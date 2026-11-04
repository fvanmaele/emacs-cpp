// S19 benchmark (T-132, D-171 .. D-173). Spike code, never promoted.
//
//   bench INDEX.dex RUNS LISTS.tsv
//
// Linked against the clangd libraries of the build tree it is built in
// (build.sh), so the same source measures pkgrel 1 and the spike's patch; built
// with -DS19_GAP for the patch, it also runs the requests with the gap field.
//
// Prints, medians of RUNS:
//   build  Dex::build of the index's slabs (SupportContainedRefs as clangd's
//          default, EnableOutgoingCalls = true), the slabs read before timing
//   memory estimateMemoryUsage of the built Dex
//   query  each of the 12 queries of RESEARCH_go_to_anything 20 per request
//          configuration: fuzzyFind with AnyScope, the limit, MiddleMatch as
//          workspace/symbol sets it (3), and with -DS19_GAP the gap field (3)
// LISTS.tsv: configuration, query, rank, qualified name, class: `fuzzy`
// (FuzzyMatcher matches), `sub` (the query inside the name, case ignored), or
// `gap` (neither: only tier 3 can have admitted it), and Dex's final score,
// recomputed after the timed runs (the callback only collects the results). Logging: errors only.

#include "FuzzyMatch.h"
#include "index/Index.h"
#include "index/Serialization.h"
#include "index/dex/Dex.h"
#include "support/Logger.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <optional>
#include <memory>
#include <string>
#include <vector>

using namespace clang::clangd;

namespace {

double nowMs() {
  using namespace std::chrono;
  return duration<double, std::milli>(steady_clock::now().time_since_epoch())
      .count();
}

double median(std::vector<double> V) {
  std::sort(V.begin(), V.end());
  return V[V.size() / 2];
}

struct Config {
  const char *Name;
  uint32_t Limit;
  unsigned Middle;
  unsigned Gap;
};

// As Dex scores: FuzzyMatcher on the whole name (template arguments too, patch
// 0012's "ector" in "EBOBaseImpl<T, true, CtorNotOnDevice>"), the substring on
// the identifier as tieredMatch cuts it.
const char *classify(llvm::StringRef Name, llvm::StringRef Query) {
  FuzzyMatcher M(Query);
  if (M.match(Name))
    return "fuzzy";
  llvm::StringRef Id = Name.take_until([](char C) { return C == '<'; });
  Id.consume_front("~");
  if (Id.find_insensitive(Query) != llvm::StringRef::npos)
    return "sub";
  return "gap";
}

// Dex's final score of a result (Dex::fuzzyFind): its match score times its
// quality (boosts are 1 for these requests: AnyScope without scopes, no
// proximity paths or types), second and third tiers transformed as there.
float finalScore(const Symbol &S, llvm::StringRef Query,
                 const FuzzyFindRequest &Req) {
  FuzzyMatcher M(Query);
  std::optional<float> Score = M.match(S.Name);
  bool Second = false, Third = false;
  if (Req.MiddleMatch && Query.size() >= Req.MiddleMatch) {
    auto Tiered = tieredMatch(S.Name, Query, Score);
    Score = Tiered ? std::optional<float>(Tiered->Score) : std::nullopt;
    Second = Tiered && !Tiered->FirstTier;
  }
#ifdef S19_GAP
  if (!Score && Req.GapMatch && Query.size() >= Req.GapMatch) {
    Score = gapMatch(S.Name, Query);
    Third = Score.has_value();
  }
#endif
  if (!Score)
    return std::numeric_limits<float>::quiet_NaN();
  float Final = *Score * quality(S);
  if (Second)
    Final = secondTierScore(Final);
  else if (Third)
    Final = thirdTierScore(Final);
  return Final;
}

} // namespace

int main(int Argc, char **Argv) {
  if (Argc != 4) {
    llvm::errs() << "usage: bench INDEX.dex RUNS LISTS.tsv\n";
    return 2;
  }
  int Runs = std::atoi(Argv[2]);
  // clangd's vlog prints each query tree; only errors, so printing is not timed.
  StreamLogger Quiet(llvm::errs(), Logger::Error);
  LoggingSession Session(Quiet);
  auto Buf = llvm::MemoryBuffer::getFile(Argv[1]);
  if (!Buf) {
    llvm::errs() << "bench: cannot read " << Argv[1] << "\n";
    return 1;
  }

  std::unique_ptr<SymbolIndex> Index;
  std::vector<double> BuildMs;
  for (int R = 0; R < Runs; ++R) {
    auto In = readIndexFile((*Buf)->getBuffer(), SymbolOrigin::Static);
    if (!In) {
      llvm::errs() << "bench: " << llvm::toString(In.takeError()) << "\n";
      return 1;
    }
    Index.reset(); // free the previous Dex before timing the next build
    double T0 = nowMs();
    Index = dex::Dex::build(std::move(*In->Symbols), std::move(*In->Refs),
                            std::move(*In->Relations),
                            /*SupportContainedRefs=*/true);
    BuildMs.push_back(nowMs() - T0);
  }
  std::printf("build median %.1f ms (min %.1f, max %.1f, %d runs)\n",
              median(BuildMs), *std::min_element(BuildMs.begin(), BuildMs.end()),
              *std::max_element(BuildMs.begin(), BuildMs.end()), Runs);
  std::printf("memory %.1f MB (estimateMemoryUsage)\n",
              Index->estimateMemoryUsage() / 1e6);

  const char *Queries[] = {"eto", "ptr", "get",    "tria", "nac", "rnm",
                           "cml", "vec", "vector", "dfh",  "fev", "qgau"};
  std::vector<Config> Configs = {
      {"plain-100", 100, 0, 0},
      {"middle-100", 100, 3, 0},
      {"middle-10000", 10000, 3, 0},
#ifdef S19_GAP
      {"gap-100", 100, 3, 3},
      {"gap-10000", 10000, 3, 3},
#endif
  };

  std::FILE *Lists = std::fopen(Argv[3], "w");
  if (!Lists) {
    llvm::errs() << "bench: cannot write " << Argv[3] << "\n";
    return 1;
  }
  for (const Config &C : Configs) {
    double Sum = 0;
    for (const char *Q : Queries) {
      FuzzyFindRequest Req;
      Req.Query = Q;
      Req.AnyScope = true;
      Req.Limit = C.Limit;
      Req.MiddleMatch = C.Middle;
#ifdef S19_GAP
      Req.GapMatch = C.Gap;
#endif
      std::vector<double> Ms;
      std::vector<const Symbol *> Found;
      for (int R = 0; R < Runs; ++R) {
        Found.clear();
        double T0 = nowMs();
        Index->fuzzyFind(Req, [&](const Symbol &S) { Found.push_back(&S); });
        Ms.push_back(nowMs() - T0);
      }
      double Med = median(Ms);
      Sum += Med;
      // After timing: class and Dex's final score of each result (the index
      // owns the symbols while it lives).
      size_t Gaps = 0;
      for (size_t I = 0; I < Found.size(); ++I) {
        const Symbol &S = *Found[I];
        const char *Class = classify(S.Name, Q);
        Gaps += llvm::StringRef(Class) == "gap";
        std::fprintf(Lists, "%s\t%s\t%zu\t%s\t%s\t%.9g\n", C.Name, Q, I + 1,
                     (S.Scope + S.Name).str().c_str(), Class,
                     finalScore(S, Q, Req));
      }
      std::printf("query %-12s %-7s %8.3f ms  %5zu results, %5zu gap\n", C.Name,
                  Q, Med, Found.size(), Gaps);
    }
    std::printf("query %-12s sum of medians %.3f ms\n", C.Name, Sum);
  }
  std::fclose(Lists);
  return 0;
}
