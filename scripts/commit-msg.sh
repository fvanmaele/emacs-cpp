#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# commit-msg.sh - three rules checked on the commit message plus the staged diff. Installed as
# .git/hooks/commit-msg by `make hook` / `just hook`; $1 is the message file.
# - Rule 15 bound: `Tier: 1` touches at most STANDARD_TIER1_FILES (3) files and
#   STANDARD_TIER1_LINES (50) added+deleted lines outside *.md; more is tier 2 or two commits.
#   A whitespace-only diff (a formatter run) is exempt from the bound (2.8.0, an adopter: a six-file
#   gofmt run was refused and split in two).
# - Rule 5: `Tier: 2` with a non-*.md file staged needs a docs/journal/NNNN-* file staged too
#   (the entry ships in the same commit; 2.3.0, from RESEARCH_adopters.md section 1). The
#   journal may sit under a subdirectory (an adopter nested in a larger repo, 2.6.0).
# - The standard's own helper files (standard.mk, standard.just, scripts/check-standard.sh,
#   scripts/commit-msg.sh) count for neither bound: vendoring them is not code (an adopter, 2.6.0).
# - Rule 10: a body with `Reasoning:` carries all three labels `What was wrong:`,
#   `Evidence:`, `Ruled out:` so `git log --grep` works (2.3.0).
# Tier-less messages pass the tier rules; merges and reverts are untouched.
set -u
msg=$1
rc=0
stat=$(git diff --cached --numstat \
    | awk '$3 ~ /\.md$/ { next }
           $3 ~ /(^|\/)(standard\.mk|standard\.just|scripts\/(check-standard|commit-msg)\.sh)$/ { next }
           { f++; if ($1 != "-") n += $1 + $2 } END { printf "%d %d", f + 0, n + 0 }')
f=${stat% *}; n=${stat#* }
if grep -qE '^Tier: *1([^0-9]|$)' "$msg" && [ -n "$(git diff --cached -w --ignore-blank-lines)" ]; then
    FILES=${STANDARD_TIER1_FILES:-3}
    LINES=${STANDARD_TIER1_LINES:-50}
    if [ "$f" -gt "$FILES" ] || [ "$n" -gt "$LINES" ]; then
        echo "commit-msg: Tier: 1 but $f files / $n changed lines outside *.md (bound $FILES / $LINES, rule 15)." >&2
        echo "commit-msg: this is tier 2 (journal entry), or split the commit." >&2
        rc=1
    fi
fi
if grep -qE '^Tier: *2([^0-9]|$)' "$msg" && [ "$f" -gt 0 ]; then
    git diff --cached --name-only | grep -qE '(^|/)docs/journal/[0-9]' \
        || { echo "commit-msg: Tier: 2 with $f non-markdown files staged and no docs/journal/NNNN-* staged" >&2
             echo "commit-msg: rule 5: the journal entry ships in the same commit." >&2; rc=1; }
fi
if grep -q '^Reasoning:' "$msg"; then
    for lbl in 'What was wrong:' 'Evidence:' 'Ruled out:'; do
        grep -q "^$lbl" "$msg" || { echo "commit-msg: Reasoning: without the label '$lbl' (rule 10)." >&2; rc=1; }
    done
fi
exit "$rc"
