#!/bin/sh
# check-standard.sh - docs consistency for a repo that adopted llm_vibecoding_standard.
# Run from the repo root (`make check` via standard.mk). Every check skips with a notice
# when its input file is absent (mid-adoption) and fails loudly otherwise. Exit 1 on any
# failure. STANDARD_WIDTH overrides the 92-column limit.
#
# Not checked, manual: every PROPOSED line in RESEARCH_*.md has a ruling in DESIGN.
set -u
WIDTH=${STANDARD_WIDTH:-92}
rc=0
fail() { printf 'check: %s\n' "$*" >&2; rc=1; }
skip() { printf 'check: skip: %s\n' "$*"; }

# Files under the standard: root docs, journal, spikes, the two shipped helpers.
docs=""
for f in ./*.md docs/journal/*.md spikes/README.md spikes/*/*.md standard.mk \
         scripts/check-standard.sh; do
    [ -f "$f" ] && docs="$docs $f"
done

# 1. ASCII only, lines <= WIDTH.
for f in $docs; do
    if LC_ALL=C grep -n '[^[:print:][:space:]]' "$f"; then
        fail "non-ASCII in $f (above)"
    fi
    awk -v w="$WIDTH" -v f="$f" \
        'length > w { printf "%s:%d: %d cols\n", f, FNR, length; bad=1 } END { exit bad }' \
        "$f" || fail "lines over $WIDTH cols in $f (above)"
done

# 2. CLAUDE.md carries the standard version stamp.
if [ -f CLAUDE.md ]; then
    grep -q '^Standard: llm_vibecoding_standard v[0-9]' CLAUDE.md \
        || fail "CLAUDE.md lacks 'Standard: llm_vibecoding_standard vX.Y.Z' line"
else skip "CLAUDE.md absent"; fi

# 3. TASKS 'done NNNN' -> docs/journal/NNNN-*.md exists.
if [ -f TASKS.md ]; then
    for n in $(grep -o 'done [0-9][0-9][0-9][0-9]' TASKS.md | awk '{print $2}' | sort -u)
    do
        ls docs/journal/"$n"-*.md >/dev/null 2>&1 \
            || fail "TASKS says done $n, no docs/journal/$n-*.md"
    done
else skip "TASKS.md absent"; fi

# 4. Journal files and JOURNAL.md index agree (rows with a real date only).
if [ -f JOURNAL.md ]; then
    for f in docs/journal/[0-9]*.md; do
        [ -f "$f" ] || continue
        n=$(basename "$f" | cut -c1-4)
        grep -q "^| $n " JOURNAL.md || fail "$f not listed in JOURNAL.md"
    done
    for n in $(grep -o '^| [0-9][0-9][0-9][0-9] | [0-9]' JOURNAL.md | awk '{print $2}'); do
        ls docs/journal/"$n"-*.md >/dev/null 2>&1 \
            || fail "JOURNAL.md lists $n, no docs/journal/$n-*.md"
    done
else skip "JOURNAL.md absent"; fi

# 5. Every D-nnn cited outside DESIGN exists as a ledger row in DESIGN.
if [ -f DESIGN.md ]; then
    cited=""
    for f in docs/journal/[0-9]*.md POSTMORTEM.md TASKS.md spikes/*/RESULTS.md; do
        [ -f "$f" ] && cited="$cited $f"
    done
    if [ -n "$cited" ]; then
        # shellcheck disable=SC2086
        for id in $(grep -oh 'D-[0-9][0-9][0-9]*' $cited | sort -u); do
            grep -q "^| $id |" DESIGN.md \
                || fail "$id cited but not in DESIGN decisions ledger"
        done
    fi
else skip "DESIGN.md absent"; fi

# 6. Risk register spikes appear in spikes/README.md; started spikes have RUN.md.
if [ -f DESIGN.md ] && [ -f spikes/README.md ]; then
    for id in $(awk '/^## Risk register/{on=1; next} /^## /{on=0} on' DESIGN.md \
                | grep -ow 'S[0-9][0-9]*' | sort -u); do
        grep -qw "$id" spikes/README.md \
            || fail "risk register names $id, spikes/README.md does not"
    done
    for id in $(grep '^| S[0-9][0-9]* |' spikes/README.md | grep -v 'not started' \
                | awk -F'|' '{ gsub(/ /, "", $2); print $2 }'); do
        grep -lq "^# $id - " spikes/*/RUN.md 2>/dev/null \
            || fail "$id started (spikes/README.md), no spikes/*/RUN.md titled '# $id - '"
    done
elif [ -f DESIGN.md ]; then skip "spikes/README.md absent"; fi

# 7. RESULTS.md opens with a filled Verdict line.
for f in spikes/*/RESULTS.md; do
    [ -f "$f" ] || continue
    v=$(grep -m1 'Verdict:' "$f")
    case "$v" in
        *"PASS / FAIL"*|"") fail "$f has no filled 'Verdict: PASS|FAIL' line" ;;
        *PASS*|*FAIL*) ;;
        *) fail "$f Verdict line is neither PASS nor FAIL: $v" ;;
    esac
done

[ "$rc" -eq 0 ] && echo "check: ok"
exit "$rc"
