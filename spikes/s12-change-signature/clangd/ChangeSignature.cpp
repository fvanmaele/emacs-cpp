//===--- ChangeSignature.cpp - S12 spike: change a function's signature ---===//
//
// Spike S12 (emacs-cpp T-069, O-43 (b)). Spike code, never promoted: a PASS
// leads to a patch written fresh.
//
// Offered on the name of a function's declaration or definition. The editor
// sends the new parameter list as the command's "input" (patch
// 0001-tweak-input.patch), for example, for `int f(int a, int b, int c)`:
//   (b, a, c)              reorder a and b
//   (a, c)                 remove b
//   (a, b, c, int d = 0)   add d; "0" is written into every existing call
//   ($1, c)                an old parameter by position, for unnamed ones
// Sites: every declaration and reference of the function in the index, plus
// the redeclarations in this file's AST. Each site is edited from the file's
// raw tokens, no parse of the calling file. A call is reported, not edited,
// when its name comes from a macro body the AST's preprocessor does not know
// (a known one has its body's call edited instead), when it is not a call (address
// taken), when its argument count does not fit this overload, when the index
// position no longer holds the name (stale), or when a `<` .. `>` holding a
// comma could be a comparison or template arguments.
//
//===----------------------------------------------------------------------===//

#include "AST.h"
#include "ParsedAST.h"
#include "Protocol.h"
#include "Selection.h"
#include "SourceCode.h"
#include "URI.h"
#include "index/Index.h"
#include "refactor/Tweak.h"
#include "support/Logger.h"
#include "clang/AST/Decl.h"
#include "clang/AST/DeclCXX.h"
#include "clang/Basic/SourceManager.h"
#include "clang/Lex/Lexer.h"
#include "clang/Lex/MacroInfo.h"
#include "clang/Lex/Preprocessor.h"
#include "clang/Tooling/Core/Replacement.h"
#include "clang/Tooling/Syntax/Tokens.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/FormatVariadic.h"
#include <chrono>
#include <map>
#include <set>
#include <optional>
#include <string>
#include <vector>

namespace clang {
namespace clangd {
namespace {

// One raw token of a file: its kind and byte offsets.
struct Token {
  tok::TokenKind Kind;
  unsigned Begin, End;
};

struct FileText {
  std::string Code;
  std::vector<Token> Tokens;
};

std::vector<Token> lexRaw(llvm::StringRef Code, const LangOptions &LangOpts) {
  SourceManagerForFile FileSM("s12-change-signature.cpp", Code);
  auto &SM = FileSM.get();
  std::vector<Token> Result;
  for (const auto &T : syntax::tokenize(SM.getMainFileID(), SM, LangOpts)) {
    unsigned Begin = SM.getFileOffset(T.location());
    Result.push_back({T.kind(), Begin, Begin + T.length()});
  }
  return Result;
}

// Index of the token starting at Offset, or -1.
int tokenAt(const std::vector<Token> &Tokens, unsigned Offset) {
  auto It = llvm::lower_bound(
      Tokens, Offset, [](const Token &T, unsigned O) { return T.Begin < O; });
  if (It == Tokens.end() || It->Begin != Offset)
    return -1;
  return It - Tokens.begin();
}

bool isOpener(tok::TokenKind K) {
  return K == tok::l_paren || K == tok::l_square || K == tok::l_brace;
}
bool isCloser(tok::TokenKind K) {
  return K == tok::r_paren || K == tok::r_square || K == tok::r_brace;
}
bool isValueToken(tok::TokenKind K) {
  return K == tok::identifier || K == tok::numeric_constant ||
         K == tok::char_constant || K == tok::string_literal ||
         K == tok::kw_true || K == tok::kw_false || K == tok::kw_nullptr ||
         K == tok::kw_this;
}

// The `>` closing the `<` at Tokens[Open], skipping nested brackets; also
// whether a comma lies directly inside it. std::nullopt when no `>` closes it
// before an unmatched closer or a `;`, that is when `<` is a comparison.
struct Angle {
  int Close;
  bool HasComma;
};
std::optional<Angle> matchAngle(const std::vector<Token> &Tokens, int Open) {
  int Angles = 1;
  std::vector<tok::TokenKind> Stack;
  bool HasComma = false;
  for (int I = Open + 1; I < (int)Tokens.size(); ++I) {
    auto K = Tokens[I].Kind;
    if (K == tok::semi)
      return std::nullopt;
    if (isOpener(K)) {
      Stack.push_back(K);
      continue;
    }
    if (isCloser(K)) {
      if (Stack.empty())
        return std::nullopt;
      Stack.pop_back();
      continue;
    }
    if (!Stack.empty())
      continue;
    if (K == tok::comma && Angles == 1)
      HasComma = true;
    else if (K == tok::less)
      ++Angles;
    else if (K == tok::greater || K == tok::greatergreater) {
      Angles -= K == tok::greater ? 1 : 2;
      if (Angles <= 0)
        return Angle{I, HasComma};
    }
  }
  return std::nullopt;
}

// The items of the list opened by the `(` at Tokens[LParen], as token index
// ranges [first, last]; the `)` in RParen. In a declaration a `<` after a name
// opens template arguments (except in a default argument); in a call it is
// judged by the token after its `>`.
struct List {
  int RParen = -1;
  std::vector<std::pair<int, int>> Items;
};
llvm::Expected<List> splitList(const std::vector<Token> &Tokens, int LParen,
                               bool IsDeclaration) {
  List Result;
  std::vector<tok::TokenKind> Stack;
  int ItemBegin = LParen + 1;
  bool InDefault = false;
  auto Close = [&](int End) {
    if (End >= ItemBegin)
      Result.Items.push_back({ItemBegin, End});
  };
  for (int I = LParen + 1; I < (int)Tokens.size(); ++I) {
    auto K = Tokens[I].Kind;
    if (isOpener(K)) {
      Stack.push_back(K);
      continue;
    }
    if (isCloser(K)) {
      if (!Stack.empty()) {
        Stack.pop_back();
        continue;
      }
      if (K != tok::r_paren)
        return error("unbalanced brackets");
      Close(I - 1);
      Result.RParen = I;
      return Result;
    }
    if (!Stack.empty())
      continue;
    if (K == tok::comma) {
      Close(I - 1);
      ItemBegin = I + 1;
      InDefault = false;
      continue;
    }
    if (K == tok::equal && IsDeclaration)
      InDefault = true;
    if (K != tok::less || I == ItemBegin)
      continue;
    auto Prev = Tokens[I - 1].Kind;
    if (Prev != tok::identifier && Prev != tok::greater &&
        !tok::isAnyIdentifier(Prev))
      continue; // `1 < x`: a comparison
    auto A = matchAngle(Tokens, I);
    if (!A) {
      if (IsDeclaration && !InDefault)
        return error("unbalanced < in a parameter list");
      continue; // a comparison
    }
    if (!A->HasComma) {
      I = A->Close; // either way no comma to split at
      continue;
    }
    if (IsDeclaration && !InDefault) {
      I = A->Close;
      continue;
    }
    auto Next = A->Close + 1 < (int)Tokens.size() ? Tokens[A->Close + 1].Kind
                                                  : tok::eof;
    if (isValueToken(Next))
      continue; // `a < b, c > d`: two comparisons
    if (Next == tok::l_paren)
      return error("ambiguous < .. > with a comma (comparisons or template "
                   "arguments)");
    I = A->Close; // `g<int, int>{}`, `h<1, 2>::v`, `p<a, b>,`
  }
  return error("no closing )");
}

struct NewParam {
  int Old = -1;          // index of the old parameter, -1 for a new one
  std::string DeclText;  // a new one: "type name"
  std::string CallValue; // a new one: the value written into every call
};

struct Site {
  bool IsDeclaration = false;
};

class ChangeSignature : public Tweak {
public:
  const char *id() const final;
  bool prepare(const Selection &Inputs) override;
  Expected<Effect> apply(const Selection &Inputs) override;
  std::string title() const override { return "Change signature"; }
  llvm::StringLiteral kind() const override {
    return CodeAction::REFACTOR_KIND;
  }

private:
  const FunctionDecl *Target = nullptr;
};

REGISTER_TWEAK(ChangeSignature)

bool ChangeSignature::prepare(const Selection &Inputs) {
  Target = nullptr;
  const SelectionTree::Node *N = Inputs.ASTSelection.commonAncestor();
  if (!N)
    return false;
  const auto *FD = N->ASTNode.get<FunctionDecl>();
  if (!FD || FD->isImplicit() || FD->isOverloadedOperator() ||
      FD->isVariadic() || FD->isMain() || isa<CXXConstructorDecl>(FD) ||
      isa<CXXDestructorDecl>(FD) || isa<CXXConversionDecl>(FD) ||
      FD->getDeclName().getNameKind() != DeclarationName::Identifier)
    return false;
  if (const auto *MD = dyn_cast<CXXMethodDecl>(FD))
    if (MD->isVirtual() || MD->getParent()->isLambda())
      return false;
  for (const ParmVarDecl *P : FD->parameters())
    if (P->isParameterPack())
      return false;
  // Only on the function's name.
  const auto &SM = Inputs.AST->getSourceManager();
  SourceLocation NameLoc = FD->getLocation();
  if (NameLoc.isMacroID() || SM.getFileID(NameLoc) != SM.getMainFileID())
    return false;
  unsigned NameBegin = SM.getFileOffset(NameLoc);
  unsigned NameEnd = NameBegin + FD->getName().size();
  if (Inputs.SelectionBegin < NameBegin || Inputs.SelectionEnd > NameEnd)
    return false;
  Target = FD;
  return true;
}

Expected<Tweak::Effect> ChangeSignature::apply(const Selection &Inputs) {
  auto Start = std::chrono::steady_clock::now();
  if (!Inputs.Index)
    return error("change signature needs the index");
  llvm::StringRef Input = llvm::StringRef(Inputs.Input).trim();
  if (!Input.consume_front("(") || !Input.consume_back(")"))
    return error("change signature: the editor sends the new parameter list "
                 "in parentheses, for example \"(b, a)\"; got \"{0}\"",
                 Inputs.Input);
  ParsedAST &AST = *Inputs.AST;
  const SourceManager &SM = AST.getSourceManager();
  const LangOptions &LangOpts = AST.getLangOpts();
  const FunctionDecl *FD = Target;
  const unsigned OldCount = FD->getNumParams();
  const std::string Name = FD->getName().str();

  // Old parameters: names (from any redeclaration naming them) and default
  // arguments' text.
  std::vector<std::string> OldNames(OldCount), Defaults(OldCount);
  for (const FunctionDecl *D : FD->redecls())
    for (unsigned I = 0; I < OldCount && I < D->getNumParams(); ++I) {
      const ParmVarDecl *P = D->getParamDecl(I);
      if (OldNames[I].empty() && !P->getName().empty())
        OldNames[I] = P->getName().str();
      if (Defaults[I].empty() && P->hasDefaultArg() &&
          !P->hasInheritedDefaultArg() && P->getDefaultArgRange().isValid())
        Defaults[I] = Lexer::getSourceText(
                          CharSourceRange::getTokenRange(
                              P->getDefaultArgRange()),
                          SM, LangOpts)
                          .str();
    }
  const unsigned MinArgs = FD->getMostRecentDecl()->getMinRequiredArguments();

  // The new list.
  std::string Spec = ("(" + Input + ")").str();
  std::vector<Token> SpecTokens = lexRaw(Spec, LangOpts);
  auto SpecList = splitList(SpecTokens, 0, /*IsDeclaration=*/true);
  if (!SpecList)
    return error("change signature: cannot read \"{0}\": {1}", Inputs.Input,
                 llvm::toString(SpecList.takeError()));
  auto SpecText = [&](int First, int Last) {
    return llvm::StringRef(Spec)
        .slice(SpecTokens[First].Begin, SpecTokens[Last].End)
        .trim()
        .str();
  };
  std::vector<NewParam> New;
  std::vector<bool> Kept(OldCount, false);
  for (auto Item : SpecList->Items) {
    int First = Item.first, Last = Item.second;
    NewParam P;
    if (First == Last && SpecTokens[First].Kind == tok::identifier) {
      std::string Word = SpecText(First, Last);
      for (unsigned I = 0; I < OldCount; ++I)
        if (Word == OldNames[I] || Word == llvm::formatv("${0}", I + 1).str())
          P.Old = I;
      if (P.Old < 0)
        return error("change signature: \"{0}\" is not a parameter of {1}; a "
                     "new one is written \"type name = value\"",
                     Word, Name);
      if (Kept[P.Old])
        return error("change signature: \"{0}\" given twice", Word);
      Kept[P.Old] = true;
    } else {
      int Equal = -1;
      for (int I = First; I <= Last && Equal < 0; ++I)
        if (SpecTokens[I].Kind == tok::equal)
          Equal = I;
      if (Equal <= First || Equal == Last)
        return error("change signature: the new parameter \"{0}\" needs a "
                     "value for the calls: \"type name = value\"",
                     SpecText(First, Last));
      P.DeclText = SpecText(First, Equal - 1);
      P.CallValue = SpecText(Equal + 1, Last);
    }
    New.push_back(std::move(P));
  }
  bool Unchanged = New.size() == OldCount;
  for (unsigned I = 0; Unchanged && I < OldCount; ++I)
    Unchanged = New[I].Old == (int)I;
  if (Unchanged)
    return error("change signature: the list is the old one");

  // Sites: the index's declarations and references, and this AST's
  // redeclarations (the preamble's headers carry no references).
  std::string MainPath = AST.tuPath().str();
  std::map<std::string, std::map<unsigned, Site>> Sites; // path -> offset
  llvm::StringMap<FileText> Files;
  auto File = [&](const std::string &Path) -> llvm::Expected<FileText *> {
    auto It = Files.find(Path);
    if (It != Files.end())
      return &It->second;
    FileText Text;
    if (Path == MainPath) {
      Text.Code = Inputs.Code.str();
    } else {
      auto Buffer = Inputs.FS->getBufferForFile(Path);
      if (!Buffer)
        return error("cannot read {0}: {1}", Path, Buffer.getError().message());
      Text.Code = (*Buffer)->getBuffer().str();
    }
    Text.Tokens = lexRaw(Text.Code, LangOpts);
    return &Files.try_emplace(Path, std::move(Text)).first->second;
  };
  unsigned IndexRefs = 0;
  std::vector<std::string> Reported;
  RefsRequest Request;
  Request.IDs.insert(getSymbolID(FD));
  llvm::Error ReadError = llvm::Error::success();
  std::vector<std::pair<std::string, unsigned>> MacroUses;
  Inputs.Index->refs(Request, [&](const Ref &R) {
    ++IndexRefs;
    if (ReadError)
      return;
    auto Path = URI::resolve(R.Location.FileURI, MainPath);
    if (!Path) {
      ReadError = Path.takeError();
      return;
    }
    auto Text = File(*Path);
    if (!Text) {
      ReadError = Text.takeError();
      return;
    }
    Position P;
    P.line = R.Location.Start.line();
    P.character = R.Location.Start.column();
    auto Offset = positionToOffset((*Text)->Code, P);
    if (!Offset) {
      Reported.push_back(llvm::formatv("{0}:{1}: indexed position beyond the "
                                       "file (stale index)",
                                       *Path, P.line + 1)
                             .str());
      llvm::consumeError(Offset.takeError());
      return;
    }
    bool IsDeclaration = static_cast<bool>(
        R.Kind & (RefKind::Declaration | RefKind::Definition));
    if (!IsDeclaration && !static_cast<bool>(R.Kind & RefKind::Spelled)) {
      MacroUses.push_back({*Path, static_cast<unsigned>(*Offset)});
      return;
    }
    Sites[*Path][*Offset].IsDeclaration |= IsDeclaration;
  });
  if (ReadError)
    return std::move(ReadError);
  for (const FunctionDecl *D : FD->redecls()) {
    SourceLocation Loc = D->getLocation();
    if (Loc.isMacroID()) {
      Reported.push_back(llvm::formatv(
          "{0}: a declaration written by a macro, not changed",
          Loc.printToString(SM)).str());
      continue;
    }
    auto FE = SM.getFileEntryRefForID(SM.getFileID(Loc));
    auto Path = FE ? getCanonicalPath(*FE, SM.getFileManager()) : std::nullopt;
    if (!Path)
      return error("no path for the declaration at {0}", Loc.printToString(SM));
    auto Text = File(*Path);
    if (!Text)
      return Text.takeError();
    Sites[*Path][SM.getFileOffset(Loc)].IsDeclaration = true;
  }
  // A call written by a macro's body: the index's reference is the macro's
  // name at the expansion. The body's call is edited once, when this AST's
  // preprocessor knows the macro and its body spells the function's name.
  Preprocessor &PP = AST.getPreprocessor();
  std::set<std::pair<std::string, unsigned>> MacroBodySites;
  for (const auto &Use : MacroUses) {
    FileText &Text = **File(Use.first);
    unsigned Line = offsetToPosition(Text.Code, Use.second).line + 1;
    int I = tokenAt(Text.Tokens, Use.second);
    std::string Macro =
        I < 0 ? "" : llvm::StringRef(Text.Code)
                         .slice(Text.Tokens[I].Begin, Text.Tokens[I].End)
                         .str();
    const MacroInfo *MI =
        Macro.empty() ? nullptr
                      : PP.getMacroInfo(PP.getIdentifierInfo(Macro));
    unsigned Found = 0;
    if (MI && MI->getDefinitionLoc().isFileID()) {
      auto FE = SM.getFileEntryRefForID(SM.getFileID(MI->getDefinitionLoc()));
      auto Path =
          FE ? getCanonicalPath(*FE, SM.getFileManager()) : std::nullopt;
      if (Path && File(*Path))
        for (const clang::Token &T : MI->tokens())
          if (T.is(tok::identifier) && T.getIdentifierInfo()->getName() == Name &&
              T.getLocation().isFileID()) {
            unsigned Offset = SM.getFileOffset(T.getLocation());
            Sites[*Path][Offset];
            MacroBodySites.insert({*Path, Offset});
            ++Found;
          }
    }
    if (!Found)
      Reported.push_back(
          llvm::formatv("{0}:{1}: a call written by the macro {2}, whose body "
                        "this file's parse does not show; not changed",
                        Use.first, Line, Macro.empty() ? "?" : Macro)
              .str());
  }

  // Calls the index also lists under another overload of this name: a
  // dependent call in a template, which resolves per instantiation.
  SymbolID TargetID = getSymbolID(FD);
  std::set<std::pair<std::string, unsigned>> OtherOverloadRefs;
  RefsRequest Others;
  for (const NamedDecl *D : FD->getDeclContext()->lookup(FD->getDeclName())) {
    const NamedDecl *Fn = D;
    if (const auto *FTD = dyn_cast<FunctionTemplateDecl>(D))
      Fn = FTD->getTemplatedDecl();
    if (!isa<FunctionDecl>(Fn))
      continue;
    SymbolID ID = getSymbolID(Fn);
    if (ID && ID != TargetID)
      Others.IDs.insert(ID);
  }
  if (!Others.IDs.empty())
    Inputs.Index->refs(Others, [&](const Ref &R) {
      auto Path = URI::resolve(R.Location.FileURI, MainPath);
      if (!Path) {
        llvm::consumeError(Path.takeError());
        return;
      }
      auto It = Files.find(*Path);
      if (It == Files.end())
        return; // no site of ours there
      Position P;
      P.line = R.Location.Start.line();
      P.character = R.Location.Start.column();
      auto Offset = positionToOffset(It->second.Code, P);
      if (!Offset) {
        llvm::consumeError(Offset.takeError());
        return;
      }
      OtherOverloadRefs.insert({*Path, static_cast<unsigned>(*Offset)});
    });
  // Calls by this name in the files read that the index lists for no overload:
  // calls through a template parameter (`m.adjust()` with `m` of type `M`).
  // Reported, as they may call another function of that name.
  for (const auto &F : Files) {
    const std::string Path = F.getKey().str();
    const FileText &Text = F.getValue();
    auto Known = Sites.find(Path);
    for (unsigned I = 0; I + 1 < Text.Tokens.size(); ++I) {
      const Token &T = Text.Tokens[I];
      auto NextKind = Text.Tokens[I + 1].Kind;
      if (T.Kind != tok::identifier ||
          (NextKind != tok::l_paren && NextKind != tok::less) ||
          llvm::StringRef(Text.Code).slice(T.Begin, T.End) != Name)
        continue;
      if ((Known != Sites.end() && Known->second.count(T.Begin)) ||
          OtherOverloadRefs.count({Path, T.Begin}))
        continue;
      Reported.push_back(
          llvm::formatv("{0}:{1}: a call by this name the index lists for no "
                        "overload (through a template parameter?); not "
                        "changed, check it",
                        Path, offsetToPosition(Text.Code, T.Begin).line + 1)
              .str());
    }
  }

  // Edits.
  unsigned Declarations = 0, Calls = 0;
  FileEdits Edits;
  for (auto &Entry : Sites) {
    const std::string &Path = Entry.first;
    auto TextOr = File(Path);
    if (!TextOr)
      return TextOr.takeError();
    FileText &Text = **TextOr;
    const auto &Tokens = Text.Tokens;
    // Last site first: a call nested in another's arguments is edited before
    // the outer one, whose items then carry the nested edits (Done: begin ->
    // end, text; the outer edit replaces the nested ones it covers).
    std::map<unsigned, std::pair<unsigned, std::string>> Done;
    auto Applied = [&](unsigned Begin, unsigned End) {
      std::string Result;
      unsigned At = Begin;
      for (auto It = Done.lower_bound(Begin);
           It != Done.end() && It->first < End; ++It) {
        Result += llvm::StringRef(Text.Code).slice(At, It->first).str();
        Result += It->second.second;
        At = It->second.first;
      }
      return Result + llvm::StringRef(Text.Code).slice(At, End).str();
    };
    for (auto Occ = Entry.second.rbegin(); Occ != Entry.second.rend(); ++Occ) {
      auto &Occurrence = *Occ;
      unsigned Offset = Occurrence.first;
      const Site &S = Occurrence.second;
      unsigned Line = offsetToPosition(Text.Code, Offset).line + 1;
      auto Report = [&](llvm::StringRef Why) {
        Reported.push_back(
            llvm::formatv("{0}:{1}: {2}", Path, Line, Why).str());
      };
      if (!S.IsDeclaration && OtherOverloadRefs.count({Path, Offset})) {
        Report("a call the index also lists for another overload (a "
               "dependent call in a template?); not changed, check it");
        continue;
      }
      int NameIndex = tokenAt(Tokens, Offset);
      if (NameIndex < 0 ||
          llvm::StringRef(Text.Code).slice(Tokens[NameIndex].Begin,
                                           Tokens[NameIndex].End) != Name) {
        Report("the indexed position no longer holds the name (stale index)");
        continue;
      }
      int Next = NameIndex + 1;
      if (Next < (int)Tokens.size() && Tokens[Next].Kind == tok::less) {
        auto A = matchAngle(Tokens, Next);
        if (!A) {
          Report("unbalanced template arguments");
          continue;
        }
        Next = A->Close + 1;
      }
      if (Next >= (int)Tokens.size() || Tokens[Next].Kind != tok::l_paren) {
        Report(S.IsDeclaration ? "a declaration without a parameter list"
                               : "not a call (for example its address "
                                 "taken), not changed");
        continue;
      }
      auto L = splitList(Tokens, Next, S.IsDeclaration);
      if (!L) {
        Report(llvm::toString(L.takeError()) + ", not changed");
        continue;
      }
      auto ItemText = [&](std::pair<int, int> Item) {
        return Applied(Tokens[Item.first].Begin, Tokens[Item.second].End);
      };
      std::vector<std::string> NewItems;
      if (S.IsDeclaration) {
        auto Items = L->Items;
        if (OldCount == 0 && Items.size() == 1 &&
            Tokens[Items[0].first].Kind == tok::kw_void &&
            Items[0].first == Items[0].second)
          Items.clear();
        if (Items.size() != OldCount) {
          Report(llvm::formatv("a declaration with {0} parameters, {1} "
                               "expected; not changed",
                               Items.size(), OldCount)
                     .str());
          continue;
        }
        for (const NewParam &P : New)
          NewItems.push_back(P.Old >= 0 ? ItemText(Items[P.Old]) : P.DeclText);
        ++Declarations;
      } else {
        unsigned Args = L->Items.size();
        if (Args < MinArgs || Args > OldCount) {
          Report(llvm::formatv("a call with {0} arguments, {1} .. {2} expected "
                               "(another overload?); not changed",
                               Args, MinArgs, OldCount)
                     .str());
          continue;
        }
        std::vector<bool> FromDefault;
        for (const NewParam &P : New) {
          if (P.Old < 0) {
            NewItems.push_back(P.CallValue);
            FromDefault.push_back(false);
          } else if (P.Old < (int)Args) {
            NewItems.push_back(ItemText(L->Items[P.Old]));
            FromDefault.push_back(false);
          } else {
            NewItems.push_back(Defaults[P.Old]);
            FromDefault.push_back(true);
          }
        }
        while (!FromDefault.empty() && FromDefault.back()) {
          FromDefault.pop_back();
          NewItems.pop_back();
        }
        ++Calls;
      }
      unsigned Begin = Tokens[Next].End, End = Tokens[L->RParen].Begin;
      // The old separators stay in place (a call over several lines keeps
      // its layout); items beyond the old count get ", ".
      std::string Joined;
      for (unsigned K = 0; K < NewItems.size(); ++K) {
        if (K > 0)
          Joined += K < L->Items.size()
                        ? llvm::StringRef(Text.Code)
                              .slice(Tokens[L->Items[K - 1].second].End,
                                     Tokens[L->Items[K].first].Begin)
                              .str()
                        : ", ";
        Joined += NewItems[K];
      }
      if (llvm::StringRef(Text.Code).slice(Begin, End) == Joined)
        continue;
      Done.erase(Done.lower_bound(Begin), Done.lower_bound(End));
      Done[Begin] = {End, Joined};
    }
    tooling::Replacements Replacements;
    for (const auto &D : Done)
      if (auto Err = Replacements.add(tooling::Replacement(
              Path, D.first, D.second.first - D.first, D.second.second)))
        return std::move(Err);
    if (!Replacements.empty())
      Edits.try_emplace(Path, Edit(Text.Code, std::move(Replacements)));
  }

  auto Ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now() - Start)
                .count();
  std::string Summary = llvm::formatv(
      "Change signature of {0}: {1} declarations and {2} calls ({3} in macro "
      "bodies) in {4} files changed, {5} reported; {6} index refs, {7} files "
      "read, {8} ms",
      Name, Declarations, Calls, MacroBodySites.size(), Edits.size(),
      Reported.size(), IndexRefs, Files.size(), Ms);
  log("S12 {0}", Summary);
  for (const auto &R : Reported)
    log("S12 reported: {0}", R);
  Effect E;
  E.ApplyEdits = std::move(Edits);
  E.FormatEdits = false;
  std::string Message = Summary;
  for (const auto &R : Reported)
    Message += "\n" + R;
  E.ShowMessage = Message;
  return E;
}

} // namespace
} // namespace clangd
} // namespace clang
