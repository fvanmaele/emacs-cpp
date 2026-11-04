// S19 classifier (T-132, D-173). Spike code, never promoted.
//
//   classify < QUERY<TAB>NAME lines > "FULL ID" lines
//
// For each line two classes as bench.cpp gives a result: `fuzzy` (clangd's
// FuzzyMatcher matches), `sub` (QUERY inside the identifier, case ignored, as
// tieredMatch cuts it), else `gap`; FULL on NAME as the reply gives it (the
// symbol's name plus its template specialization arguments), ID on the
// identifier before any `<`. Dex and FindSymbols match the symbol's name,
// which lies between the two. Built with build.sh (SRC=classify.cpp)
// against the tree's own FuzzyMatcher, so compare.py can check the order of
// workspace/symbol replies, whose exposed score is not the one they rank by.

#include "FuzzyMatch.h"
#include "llvm/ADT/StringRef.h"
#include <iostream>
#include <string>

using namespace clang::clangd;

int main() {
  std::string Line;
  while (std::getline(std::cin, Line)) {
    llvm::StringRef L(Line);
    auto [Query, Name] = L.split('\t');
    llvm::StringRef Id = Name.take_until([](char C) { return C == '<'; });
    Id.consume_front("~");
    auto Class = [&](llvm::StringRef Word) {
      FuzzyMatcher M(Query);
      if (M.match(Word))
        return "fuzzy";
      return Id.find_insensitive(Query) != llvm::StringRef::npos ? "sub" : "gap";
    };
    std::cout << Class(Name) << " " << Class(Id) << "\n";
  }
  return 0;
}
