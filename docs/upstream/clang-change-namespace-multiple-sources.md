# LLVM issue draft: clang-change-namespace crashes on two or more source files

Draft for https://github.com/llvm/llvm-project/issues (component clang-tools-extra).
Not sent; the owner sends it (D-094). Checked 2026-10-14: `main`'s
`ChangeNamespace.cpp` still never clears `MoveNamespaces` / `InsertFwdDecls`. The
fix below ships as `packaging/clang-change-namespace/0001-...patch` (D-097).

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

### Fix
Clear `MoveNamespaces` and `InsertFwdDecls` at the end of
`onEndOfTranslationUnit`; their replacements are merged into `FileToReplacements` by
then.

```diff
--- a/clang-tools-extra/clang-change-namespace/ChangeNamespace.cpp
+++ b/clang-tools-extra/clang-change-namespace/ChangeNamespace.cpp
@@ -1003,6 +1003,13 @@
   for (auto &Entry : FileToReplacements)
     if (!FilePatternRE.match(Entry.first))
       Entry.second.clear();
+
+  // The moves and insertions above refer to this translation unit's
+  // SourceManager and FileIDs; they are merged into FileToReplacements now and
+  // must not be replayed at the end of the next translation unit, whose
+  // SourceManager is a different one (the previous one is gone).
+  MoveNamespaces.clear();
+  InsertFwdDecls.clear();
 }
 
 } // namespace change_namespace
```

Tested (2026-10-14): the tool built from 23.1.1's sources with this change, linked
against MacPorts' LLVM 23.1.3 libraries, on the reproduction above with two and with
three sources (a third one also defining code in `geom`): exit 0, the header and each
source moved to `namespace shapes` once, no duplicated edits, the changed sources
compile. (Uses outside the old namespace, `geom::Circle` in `main()`, are not changed,
which is the tool's documented scope, not part of this report.)
