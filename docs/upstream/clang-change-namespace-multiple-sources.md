# LLVM issue draft: clang-change-namespace crashes on two or more source files

Draft for https://github.com/llvm/llvm-project/issues (component clang-tools-extra).
Not sent; the owner sends it (D-094). Checked 2026-10-14: `main`'s
`ChangeNamespace.cpp` still never clears `MoveNamespaces` / `InsertFwdDecls`.

---

**Title:** [clang-change-namespace] use-after-free crash when given two or more
source files (MoveNamespaces kept across translation units)

### Environment
clang-change-namespace from LLVM 23.1.3 (MacPorts, arm64 macOS); the code in
question is unchanged in 23.1.1 and on `main`.

### Reproduction
```
include/geom/shapes.h:  namespace geom { class Circle { ... }; class Square { ... }; }
src/shapes.cc:          #include "geom/shapes.h"  namespace geom { ...definitions... }
src/main.cc:            #include "geom/shapes.h"  int main() { geom::Circle c(1.0); ... }

clang-change-namespace -old_namespace=geom -new_namespace=shapes \
    -file_pattern='.*' -p build src/main.cc src/shapes.cc
```
Exit 139 (SIGSEGV). With one source file it runs.

### Stack
```
#4 clang::SourceManager::getBufferData(clang::FileID, bool*) const
#5 clang::change_namespace::ChangeNamespaceTool::onEndOfTranslationUnit()
#6 clang::ast_matchers::MatchFinder::matchAST(clang::ASTContext&)
#7 clang::ParseAST(clang::Sema&, bool, bool)
```

### Cause
`moveOldNamespace` stores, per file, a `MoveNamespace` with `SourceMgr =
Result.SourceManager` and a `FileID` into the member map `MoveNamespaces`.
`onEndOfTranslationUnit` loops over every entry of `MoveNamespaces` and calls
`SM.getBufferData(NsMoves.begin()->FID)` through the stored `SourceMgr`; the map (and
`InsertFwdDecls`) is never cleared. At the end of the second translation unit the
entries of the first one are still there, and their `SourceManager` was destroyed
with the first translation unit's AST: a dangling pointer.

### Possible fix
Clear `MoveNamespaces` and `InsertFwdDecls` at the end of
`onEndOfTranslationUnit` (their replacements are already merged into
`FileToReplacements`). Not tried here; a header moved in several translation units
then gets its replacements computed more than once, which `addOrMergeReplacement`
would have to absorb.
