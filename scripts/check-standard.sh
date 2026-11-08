#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# check-standard.sh - docs consistency for a repo that adopted llm_vibecoding_standard.
# Run from the repo root (`make docs-check` via standard.mk, `just docs-check` via
# standard.just). Every check skips with a notice
# when its input file is absent (mid-adoption) and fails loudly otherwise. Exit 1 on any
# failure. STANDARD_WIDTH overrides the 128-column prose limit; 0 turns the width pass
# off (research repos). STANDARD_TYPOGRAPHY=fail turns the typography note (dashes, smart
# quotes, ellipsis, emoji in docs) into a failure, fenced code blocks exempt; default note.
# STANDARD_SKIP lists docs the check never reads (fork only). STANDARD_CODE_UNICODE lists
# code files that must keep their non-ASCII (each backed by a D-row): localized UI text or a
# test of it, a test fixture of real data (accented names), a file the repo never edits (an
# applied migration); they skip the ASCII pass and still get the typography note (2.9.0, a
# Czech dashboard; 2.14.0, an adopter's frozen migration and real-name fixtures).
# STANDARD_FORK_BASE=<git ref> (forks): the code-ASCII pass reads only lines ADDED since
# that ref, so upstream's unicode is not this fork's problem (from a fork adopter's request).
#
# Not checked, manual: every PROPOSED line in RESEARCH_*.md has a ruling in DESIGN.
set -u
WIDTH=${STANDARD_WIDTH:-128}
TYPO=${STANDARD_TYPOGRAPHY:-note}
rc=0
fail() { printf 'check: %s\n' "$*" >&2; rc=1; }
skip() { printf 'check: skip: %s\n' "$*"; }
case "$TYPO" in note|fail) ;; *) fail "STANDARD_TYPOGRAPHY takes note or fail, not '$TYPO'"; TYPO=note ;; esac

# STANDARD_SKIP (space-separated, repo-relative paths): docs and code files this check never
# reads. Only for files the owner does not own: an upstream readme in a fork, a vendored tree
# (README section "Adopting in a FORK"). A trailing slash is a directory prefix
# (`vendor/eframe/`); globs are still rejected. Strict: an entry that is a pattern, names an
# artifact of this standard, or matches no file the check reads fails. Skipped docs are
# printed; skipped code files are counted (2.2.0, from an adopter's handoff).
protected() {
    case "$1" in
        DESIGN.md|TASKS.md|TODO_human.md|JOURNAL.md|POSTMORTEM.md|CLAUDE.md) return 0 ;;
        RESEARCH_*.md) return 0 ;;
        docs/journal/*|spikes/*|standard.mk|standard.just|scripts/check-standard.sh|scripts/commit-msg.sh) return 0 ;;
    esac
    return 1
}
SKIP=""
set -f
for s in ${STANDARD_SKIP:-}; do
    s=${s#./}
    case "$s" in
        *[*?[]*) fail "STANDARD_SKIP takes plain paths, not patterns: $s"; continue ;;
    esac
    if protected "$s"; then
        fail "STANDARD_SKIP names $s, an artifact of this standard; it is still checked"
    else
        SKIP="$SKIP $s"
    fi
done
CODEU=""
set -f
for u in ${STANDARD_CODE_UNICODE:-}; do
    u=${u#./}
    case "$u" in
        *[*?[]*) fail "STANDARD_CODE_UNICODE takes plain file paths, not patterns: $u"; continue ;;
    esac
    [ -f "$u" ] || { fail "STANDARD_CODE_UNICODE names $u, which is not a file"; continue; }
    CODEU="$CODEU $u"
done
set +f
listed_unicode() {
    for u in $CODEU; do [ "${1#./}" = "$u" ] && return 0; done
    return 1
}
skipped() {
    for s in $SKIP; do
        case "$s" in
            */) case "${1#./}" in "$s"*) return 0 ;; esac ;;
            *) [ "${1#./}" = "$s" ] && return 0 ;;
        esac
    done
    return 1
}
# which SKIP entry matched a path (for the "matched nothing" validation after check 9)
skip_entry() {
    for s in $SKIP; do
        case "$s" in
            */) case "${1#./}" in "$s"*) printf '%s' "$s"; return ;; esac ;;
            *) [ "${1#./}" = "$s" ] && { printf '%s' "$s"; return; } ;;
        esac
    done
}

# Files under the standard: root docs, journal, spikes, the two shipped helpers. Inside a
# git work tree, gitignored files are skipped: a scratch note (todo.now.md) is not a
# project doc. New, not-yet-added files ARE checked - `make check` runs before the commit
# that adds them (1.1.0 checked tracked files only and let a new journal entry through).
ignored() { git check-ignore -q -- "$1" 2>/dev/null; }
in_git=0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_git=1
docs=""
matched=$(mktemp)
for f in ./*.md docs/journal/*.md spikes/README.md spikes/*/*.md standard.mk \
         standard.just scripts/check-standard.sh; do
    [ -f "$f" ] || continue
    case "$f" in ./*_handoff.md) continue ;; esac
    [ "$in_git" -eq 1 ] && ignored "$f" && continue
    if skipped "$f"; then
        skip "${f#./} (STANDARD_SKIP)"
        skip_entry "$f" >> "$matched"; echo >> "$matched"
        continue
    fi
    docs="$docs $f"
done

# 1. Docs: typography notes and prose width. Non-ASCII in docs is allowed (place names,
# degree signs, the content's own symbols). Em/en dashes, smart quotes, ellipsis and emoji
# are discouraged: counted per file and printed as a note. STANDARD_TYPOGRAPHY=fail makes
# each such line a failure instead (2.8.0, an adopter whose owner ruled dashes out needs
# the hook to hold it); lines inside fenced code blocks are exempt, a box-drawn mockup is
# not prose. Width: two kinds of line cannot be wrapped and are exempt: markdown table
# rows, and lines holding one unbreakable token of 60+ characters (URLs, `[path:line]`).
for f in $docs; do
    if [ "$TYPO" = fail ]; then
        LC_ALL=C awk -v f="$f" '
            /^[ \t]*(```|~~~)/ { fence = !fence; next }
            fence { next }
            /\342\200[\223\224]/ || /\342\200[\230-\235]/ || /\342\200\246/ || /\360\237[\214-\253]/ || /\342[\230-\236]/ {
                printf "%s:%d: typography (dash, smart quote, ellipsis or emoji)\n", f, FNR; bad = 1 }
            END { exit bad }' "$f" || fail "typography in ${f#./} (above); STANDARD_TYPOGRAPHY=fail"
    fi
    t=$(LC_ALL=C awk '
        /\342\200[\223\224]/ { d++ }
        /\342\200[\230-\235]/ { q++ }
        /\342\200\246/ { e++ }
        /\360\237[\214-\253]/ || /\342[\230-\236]/ { m++ }
        END { if (d + q + e + m) printf "%d dash, %d quote, %d ellipsis, %d emoji lines", d, q, e, m }' "$f")
    [ -n "$t" ] && printf 'check: note: typography in %s: %s\n' "${f#./}" "$t"
    [ "$WIDTH" -eq 0 ] && continue
    # The standard's own helpers are wrapped at 128 upstream; a narrower house width is the
    # project's rule, not theirs (2.6.0, an adopter's handoff: width 92 failed on them, unfixable).
    case "$f" in standard.mk|standard.just|scripts/check-standard.sh) continue ;; esac
    awk -v w="$WIDTH" -v f="$f" '
        length <= w { next }
        /^[ \t]*\|/ { next }
        { for (i = 1; i <= NF; i++) if (length($i) >= 60) next }
        { printf "%s:%d: %d cols\n", f, FNR, length; bad = 1 }
        END { exit bad }' \
        "$f" || fail "lines over $WIDTH cols in $f (above)"
done

# 0. A pending handoff is applied first: a note with its age, never a failure (2.16.2). A
# failure was cleared by moving or deleting the file (2.10.0, an adopter parked one outside
# its repo; 2.16.1, an adopter deleted an unapplied one) and blocked unrelated commits.
for h in ./*_handoff.md; do
    [ -f "$h" ] || continue
    days=0; for d in 1 2 3 7 14 30; do [ -n "$(find "$h" -mtime +$((d - 1)) 2>/dev/null)" ] && days=$d; done
    case $days in 0) age="under a day" ;; 1) age="1 day" ;; *) age="$days days or more" ;; esac
    printf 'check: note: %s pending %s: apply it first; never delete it unapplied (rule 24)\n' "${h#./}" "$age"
done

# 2. CLAUDE.md carries the standard version stamp.
if [ -f CLAUDE.md ]; then
    grep -q '^Standard: llm_vibecoding_standard v[0-9]' CLAUDE.md \
        || fail "CLAUDE.md lacks 'Standard: llm_vibecoding_standard vX.Y.Z' line"
else skip "CLAUDE.md absent"; fi

# 3. TASKS 'done NNNN' -> docs/journal/NNNN-*.md exists. Four digits standing alone only: a tier 1
# row cites its commit (`done 8822658`), which is no journal 8822 (2.17.0, an adopter's request).
if [ -f TASKS.md ]; then
    for n in $(awk '{ s = $0
            while (match(s, /done [0-9][0-9][0-9][0-9]/)) {
                if (substr(s, RSTART + RLENGTH, 1) !~ /[0-9A-Za-z]/) print substr(s, RSTART + 5, 4)
                s = substr(s, RSTART + RLENGTH) } }' TASKS.md | sort -u)
    do
        ls docs/journal/"$n"-*.md >/dev/null 2>&1 \
            || fail "TASKS says done $n, no docs/journal/$n-*.md"
    done
else skip "TASKS.md absent"; fi

# 15. A task marked done while its owner run is still queued: a note on a TASKS row 'done
# NNNN' that cites an H-n still listed in TODO_human.md (rule 2: the real run is part of
# done; 2.10.0, an adopter's audit found nothing read the queue).
if [ -f TASKS.md ] && [ -f TODO_human.md ]; then
    grep -E '^[|] *T-[0-9]+ *[|] *done [0-9]{4}' TASKS.md | while IFS= read -r row; do
        t=$(printf '%s\n' "$row" | grep -o 'T-[0-9]*' | head -n 1)
        for h in $(printf '%s\n' "$row" | grep -o -w 'H-[0-9]*' | sort -u); do
            grep -q "[*][*]${h}[*][*]" TODO_human.md \
                && printf 'check: note: TASKS %s is done but cites %s, still open in TODO_human.md (rule 2)\n' "$t" "$h"
        done
    done
fi

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

# 5. Every D-nnn cited outside DESIGN exists as a ledger row in DESIGN. Another repo's
# decision is cited as `<repo>:D-nnn` and skipped: the id must not follow a colon or a
# word character. Defect ids (`Dn`, no hyphen) never match.
if [ -f DESIGN.md ]; then
    cited=""
    for f in docs/journal/[0-9]*.md POSTMORTEM.md TASKS.md spikes/*/RESULTS.md; do
        [ -f "$f" ] && cited="$cited $f"
    done
    if [ -n "$cited" ]; then
        # shellcheck disable=SC2086
        for id in $(grep -ohE '(^|[^[:alnum:]_:])D-[0-9]{2,}' $cited \
                    | grep -oE 'D-[0-9]+' | sort -u); do
            grep -q "^| $id |" DESIGN.md \
                || fail "$id cited but not in DESIGN decisions ledger"
        done
    fi
else skip "DESIGN.md absent"; fi

# 5b. Every B-n (a benchmark, rule 16) cited in the same files has a `| B-n |` row in a doc
# with a "Benchmarks by id" heading. `<repo>:B-n` and another document's `<prefix>:B-n`
# are skipped, and so is a B-n inside a longer id (`PK-B-000`) (2.15.0, from an adopter's
# request; owner, 2026-10-20).
bcited=""
for f in docs/journal/[0-9]*.md POSTMORTEM.md TASKS.md spikes/*/RESULTS.md; do
    [ -f "$f" ] && bcited="$bcited $f"
done
# shellcheck disable=SC2086
bids=$([ -n "$bcited" ] && grep -ohE '(^|[^[:alnum:]_:-])B-[0-9]+' $bcited | grep -oE 'B-[0-9]+' | sort -u)
if [ -n "$bids" ]; then
    bdocs=$(if [ "$in_git" -eq 1 ]; then git ls-files '*.md'; else find . -xdev -name '*.md' ! -path './.git/*' \
        | sed 's|^\./||'; fi | while IFS= read -r f; do
            [ -f "$f" ] && grep -qE '^#{1,6} Benchmarks by id' "$f" && printf '%s\n' "$f"; done)
    if [ -z "$bdocs" ]; then
        fail "$(echo $bids | tr ' ' ',') cited but no doc has a \"Benchmarks by id\" table (rule 16)"
    else
        for id in $bids; do
            # shellcheck disable=SC2086
            grep -qE "^\| *$id *\|" $bdocs || fail "$id cited but not in the Benchmarks by id table ($bdocs)"
        done
    fi
fi

# 6. Risk register spikes appear in spikes/README.md; started spikes have RUN.md. A spike id is
# `S` digits and an optional lowercase letter suffix, a split spike (2.16.6, an adopter's request).
if [ -f DESIGN.md ] && [ -f spikes/README.md ]; then
    grep -q '^## .*Risk register' DESIGN.md \
        || skip "DESIGN.md has no '## ... Risk register' heading; check 6 reads no risk"
    for id in $(awk '/^## .*Risk register/{on=1; next} /^## /{on=0} on' DESIGN.md \
                | grep -ow 'S[0-9][0-9]*[a-z]*' | sort -u); do
        grep -qw "$id" spikes/README.md \
            || fail "risk register names $id, spikes/README.md does not"
    done
    for id in $(grep '^| S[0-9][0-9]*[a-z]* |' spikes/README.md | grep -v 'not started' \
                | awk -F'|' '{ gsub(/ /, "", $2); print $2 }'); do
        grep -lq "^# $id - " spikes/*/RUN.md 2>/dev/null \
            || fail "$id started (spikes/README.md), no spikes/*/RUN.md titled '# $id - '"
    done
elif [ -f DESIGN.md ]; then skip "spikes/README.md absent"; fi

# 7. A spike that ran has a filled verdict: RUN.md present means RESULTS.md exists and opens
# with `Verdict: PASS` or `Verdict: FAIL` (2.3.0: 25 spike dirs without a verdict, survey).
for sd in spikes/*/; do
    [ -d "$sd" ] || continue
    [ -f "$sd/RUN.md" ] || [ -f "$sd/RESULTS.md" ] || continue
    f="$sd/RESULTS.md"
    if [ ! -f "$f" ]; then
        # Status `ready` in spikes/README.md: RUN.md written for the owner (rule 4), not run yet
        # (2.6.0, an adopter's request: a placeholder verdict would be a false record).
        # Status `running`: a spike that runs for weeks has no verdict yet; a note with RUN.md's age
        # (2.17.0, an adopter's month-long spike; an abandoned one is still seen).
        id=$(sed -n 's/^# \(S[0-9][0-9]*[a-z]*\) - .*/\1/p' "$sd/RUN.md" | head -n 1)
        if [ -n "$id" ] && [ -f spikes/README.md ] && grep -q "^| $id | ready" spikes/README.md; then continue; fi
        if [ -n "$id" ] && [ -f spikes/README.md ] && grep -q "^| $id | running" spikes/README.md; then
            t=$(git log --diff-filter=A --format=%ct -- "$sd/RUN.md" 2>/dev/null | tail -n 1)
            if [ -n "$t" ]; then age="$(( ($(date +%s) - t) / 86400 )) days since RUN.md was first committed"
            else age="RUN.md not committed yet"; fi
            printf 'check: note: %s: %s running, %s; RESULTS.md with its verdict closes it\n' "${sd%/}" "$id" "$age"
            continue
        fi
        fail "${sd%/}: RUN.md present, no RESULTS.md (verdict not written; status 'ready' or 'running' if not run yet)"
        continue
    fi
    v=$(grep -m1 'Verdict:' "$f")
    case "$v" in
        *"PASS / FAIL"*|"") fail "$f has no filled 'Verdict: PASS|FAIL' line" ;;
        *PASS*|*FAIL*) ;;
        *) fail "$f Verdict line is neither PASS nor FAIL: $v" ;;
    esac
done

# 8. CLAUDE.md carries no template placeholders. Exact phrases from templates/CLAUDE.md
# only; DESIGN's `TO FILL` is legal (owner input pending by design).
if [ -f CLAUDE.md ]; then
    if grep -nF -e '<Project>' -e '<test command>' -e 'Reason: <' -e '<the dead direction' \
            -e '<Project-specific invariant>' -e 'v<STANDARD_VERSION>' -e '<...>' CLAUDE.md; then
        fail "CLAUDE.md still carries template placeholders (above); fill or delete them"
    fi
fi

# 9. Code is ASCII. Tracked source files (git ls-files; outside git: find -xdev), picked by
# extension or by a shebang on an extensionless file; docs/, *.md and STANDARD_SKIP paths
# excluded. A byte class in awk, not `grep '[^[:print:]]'`: ugrep installed as grep
# matches no UTF-8 byte with that class, so the 1.x check could never fail (found in an adopter, 2.0.0).
# Config files count as code, and a template is read as the file it becomes: a trailing
# .example, .sample, .in or .dist is dropped before the match (2.14.0: an adopter's
# config.env.example, installed as its /etc config, carried 23 non-ASCII lines unseen).
code_ext='\.(c|h|cc|cpp|hpp|rs|go|py|sh|bash|mk|toml|json|ya?ml|js|ts|gd|cs|java|kt|zig|lua|sql|html|css|just|'
code_ext=$code_ext'env|ini|cfg|conf|service)$'
list=$(mktemp) && out=$(mktemp) && umatched=$(mktemp)
if [ "$in_git" -eq 1 ]; then git ls-files; else find . -xdev -type f ! -path './.git/*' | sed 's|^\./||'; fi \
| while IFS= read -r f; do
    [ -f "$f" ] || continue
    case "$f" in docs/*|*.md) continue ;; esac
    if skipped "$f"; then skip_entry "$f" >> "$matched"; echo >> "$matched"; continue; fi
    if listed_unicode "$f"; then printf '%s\n' "$f" >> "$umatched"; continue; fi
    # Binary files are not code: a NUL byte in the first KiB skips the file (an adopter's MPEG-TS
    # fixtures end in .ts and read as TypeScript, 1,258 "non-ASCII lines").
    if [ "$(head -c 1024 "$f" | tr -d '\000' | wc -c)" -ne "$(head -c 1024 "$f" | wc -c)" ]; then continue; fi
    b=${f##*/}
    if printf '%s' "$f" | sed -E 's/\.(example|sample|in|dist)$//' | grep -qE "$code_ext"; then printf '%s\n' "$f"
    elif [ "$b" = Makefile ] || [ "$b" = justfile ] || [ "$b" = Justfile ]; then printf '%s\n' "$f"
    elif [ "${b#*.}" = "$b" ] && [ "$(head -c2 "$f" 2>/dev/null)" = '#!' ]; then printf '%s\n' "$f"
    fi
done > "$list"
BASE=${STANDARD_FORK_BASE:-}
if [ -n "$BASE" ] && [ "$in_git" -ne 1 ]; then
    fail "STANDARD_FORK_BASE set but this is not a git work tree"
elif [ -n "$BASE" ] && ! git rev-parse --verify -q "$BASE^{commit}" >/dev/null; then
    fail "STANDARD_FORK_BASE=$BASE does not resolve to a commit"
elif [ -s "$list" ] && [ -n "$BASE" ]; then
    # Fork mode: only lines added since BASE, line numbers from the hunk headers.
    tr '\n' '\0' < "$list" | xargs -0 -r git diff -U0 --no-color --no-ext-diff "$BASE" -- \
        | LC_ALL=C awk '
            /^\+\+\+ b\// { f = substr($0, 7); next }
            /^@@/ { split($3, a, /[,+]/); ln = a[2]; next }
            /^\+/ { if ($0 ~ /[\200-\377]/) printf "%s:%d: non-ASCII (added since base)\n", f, ln; ln++ }' > "$out"
    if [ -s "$out" ]; then cat "$out" >&2; fail "non-ASCII in code added since $BASE (above)"; fi
elif [ -s "$list" ]; then
    tr '\n' '\0' < "$list" | xargs -0 -r env LC_ALL=C awk \
        '/[\200-\377]/ { printf "%s:%d: non-ASCII\n", FILENAME, FNR }' > "$out"
    if [ -s "$out" ]; then cat "$out" >&2; fail "non-ASCII in code (above); code is ASCII, docs may not be"; fi
fi
# STANDARD_CODE_UNICODE: strict like STANDARD_SKIP; a listed file is noted, never silent.
for u in $CODEU; do
    grep -qxF -- "$u" "$umatched" \
        || fail "STANDARD_CODE_UNICODE names $u, which the code pass does not read (a doc, or in STANDARD_SKIP)"
done
while IFS= read -r u; do
    n=$(LC_ALL=C awk '/[\200-\377]/ { n++ } END { print n + 0 }' "$u")
    printf 'check: note: %s: %s non-ASCII lines allowed by STANDARD_CODE_UNICODE (a D-nnn backs the entry)\n' "$u" "$n"
done < "$umatched"
rm -f "$umatched"

# 11. Never kill a process by name or pattern (rule 25). Check 9's file list, comments
# stripped (`//` in C-family and Rust, `#` elsewhere): `pkill`, `killall`, `kill` fed by
# `$(pgrep ...)`, `$(pidof ...)` or backticks, and `pgrep`/`pidof` piped into `xargs kill` fail
# with path:line. 2026-10-08: `pkill -u $(id -u) -x foot` closed every terminal of the owner
# and the Claude session with them (an adopter's handoff). The standard's own checker is exempt.
if [ -s "$list" ]; then
    grep -vx 'scripts/check-standard.sh' "$list" | tr '\n' '\0' | xargs -0 -r awk '
        function bad() { printf "%s:%d: kill by process name or pattern\n", FILENAME, FNR }
        { line = $0 }
        FILENAME ~ /\.(rs|go|c|h|cc|cpp|hpp|cs|java|kt|zig|js|ts|gd)$/ { sub(/\/\/.*/, "", line) }
        FILENAME !~ /\.(rs|go|c|h|cc|cpp|hpp|cs|java|kt|zig|js|ts|gd)$/ { sub(/#.*/, "", line) }
        line ~ /(^|[^A-Za-z0-9_])(pkill|killall)([^A-Za-z0-9_]|$)/ { bad(); next }
        line ~ /kill[^|]*(\$\(|`) *(pgrep|pidof)/ { bad(); next }
        line ~ /(pgrep|pidof)[^|]*\|[^|]*xargs[^|]*kill/ { bad(); next }' > "$out"
    if [ -s "$out" ]; then
        cat "$out" >&2
        fail "kill by process name or pattern (above); rule 25: kill only a pid you recorded, or its process group"
    fi
fi
rm -f "$list" "$out"

# 10. An answered one-shot request is deleted in the ruling commit (README "<consumer>_request.md";
# owner 2026-10-07: "answered requests should be removed", 1,800 lines piled up in a week).
# `Kind: one-shot` in the header; answered = "Reciprocal notes" holds more than "(none yet)".
for f in ./*_request.md; do
    [ -f "$f" ] || continue
    grep -q '^Kind: *one-shot' "$f" || continue
    notes=$(awk '/^## Reciprocal notes/ { on = 1; next } /^## / { on = 0 } on && NF && !/^\(none yet\)/' "$f")
    [ -z "$notes" ] || fail "${f#./}: one-shot request answered (Reciprocal notes filled); delete it in the ruling commit"
done

# 12. Owner handovers are steps in chat, never pointers to documents (rule 4): notes, not
# failures. An H-n item that names RUN.md; a spikes/*/RUN.md with more than 5 lines inside
# code fences, a copy-paste list in the making (2.9.0, two device handoffs the same week).
# Only the queue's sections count: the template's own preamble says "never a pointer to
# RUN.md" and tripped the note in every adopter (2.10.0, an adopter's feedback).
if [ -f TODO_human.md ]; then
    n=$(awk '/^## / { on = 1 } on && /RUN\.md/ { n++ } END { print n + 0 }' TODO_human.md)
    [ "$n" -gt 0 ] && printf 'check: note: TODO_human.md names RUN.md on %s lines; an H-n carries its steps (rule 4)\n' "$n"
fi
# An H-n step that uses a shell variable no step of the same item sets: a new terminal has
# it empty (2.10.0, an adopter: an unset variable sent scp to the wrong account). Variables
# every shell has are skipped.
if [ -f TODO_human.md ]; then
    awk '
        BEGIN { n = split("HOME USER LOGNAME PWD OLDPWD PATH SHELL TERM LANG LC_ALL TMPDIR " \
                          "EDITOR VISUAL DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR XDG_CONFIG_HOME " \
                          "XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME UID EUID HOSTNAME RANDOM " \
                          "SECONDS PPID", a, " ")
                for (i = 1; i <= n; i++) always[a[i]] = 1 }
        function flush(   v) {
            if (item != "")
                for (v in used)
                    if (!(v in set) && !(v in always))
                        printf "check: note: TODO_human.md %s uses $%s, which no step of it sets (rule 4)\n", item, v
            split("", used); split("", set) }
        /^## / { flush(); item = ""; on = 1; next }
        !on { next }
        /^- \*\*H-[0-9]+\*\*/ { flush(); match($0, /H-[0-9]+/); item = substr($0, RSTART, RLENGTH) }
        item == "" { next }
        { line = $0
          while (match(line, /[$][{]?[A-Za-z_][A-Za-z0-9_]*/)) {
              v = substr(line, RSTART, RLENGTH); sub(/^[$][{]?/, "", v); used[v] = 1
              line = substr(line, RSTART + RLENGTH) }
          line = $0
          while (match(line, /(^|[^A-Za-z0-9_$])[A-Za-z_][A-Za-z0-9_]*=/)) {
              v = substr(line, RSTART, RLENGTH); sub(/=$/, "", v); sub(/^[^A-Za-z_]/, "", v); set[v] = 1
              line = substr(line, RSTART + RLENGTH) }
          line = $0
          while (match(line, /(read( -r)?|for) [A-Za-z_][A-Za-z0-9_]*/)) {
              v = substr(line, RSTART, RLENGTH); sub(/^(read( -r)?|for) /, "", v); set[v] = 1
              line = substr(line, RSTART + RLENGTH) } }
        END { flush() }' TODO_human.md
fi
for f in spikes/*/RUN.md; do
    [ -f "$f" ] || continue
    n=$(awk '/^[ \t]*```/ { fence = !fence; next } fence && NF { n++ } END { print n + 0 }' "$f")
    [ "$n" -gt 5 ] && printf 'check: note: %s holds %s lines inside code fences; the session runs them (rule 4)\n' "$f" "$n"
done

# 13. No first-person authorship for the owner (rule 27): a note, never a failure, on the
# obvious forms in docs outside fenced blocks. The release precheck of the owner's public
# release standard does the hard version.
for f in $docs; do
    awk -v f="$f" '
        /^[ \t]*(```|~~~)/ { fence = !fence; next }
        fence { next }
        /(^|[^A-Za-z])I (wrote|built|coded|developed|made|implemented)([^A-Za-z]|$)/ {
            printf "check: note: %s:%d: first-person authorship (rule 27: the owner had it written)\n", f, FNR }' "$f"
done

# 14. A generated STATUS.md (a dashboard's) is never tracked: a note when git tracks it
# (2.10.0, the owner's dashboard: 97 repos tracked its file and stayed dirty).
if [ "$in_git" -eq 1 ] && git ls-files --error-unmatch STATUS.md >/dev/null 2>&1; then
    printf 'check: note: STATUS.md is tracked; it is generated: git rm --cached STATUS.md, add /STATUS.md to .gitignore\n'
fi

# 16. A TASKS row is one result, at most L (rule 30): a note when one T-nnn is the first id of more
# than 3 JOURNAL.md index rows; `<repo>:T-nnn` and longer ids are skipped, and so is a row TASKS.md
# marks done: the note is for a row still growing (2.16.0: an adopter's row sized L ran to 19
# entries; 2.16.1: every row it noted across the fleet was already done). Only the first id
# counts, the entry's work; later ones are citations (2.17.0: an adopter's research entries named
# a task they fed, and it was noted though nobody had worked on it).
if [ -f JOURNAL.md ]; then
    done_ids=$([ -f TASKS.md ] && awk -F'|' '$2 ~ /^ *T-[0-9]+ *$/ && $3 ~ /^ *done/ {
        gsub(/ /, "", $2); printf "%s ", $2 }' TASKS.md)
    awk -v done_ids=" $done_ids" '/^\| *[0-9][0-9][0-9][0-9] / {
            s = $0; off = 0
            while (match(s, /T-[0-9]+/)) {
                at = off + RSTART; c = at > 1 ? substr($0, at - 1, 1) : ""
                id = substr(s, RSTART, RLENGTH)
                if (c !~ /[A-Za-z0-9_:-]/) { n[id]++; break }
                off += RSTART + RLENGTH - 1; s = substr(s, RSTART + RLENGTH)
            } }
        END { for (id in n) if (n[id] > 3 && index(done_ids, " " id " ") == 0)
            printf "check: note: %s is the work of %d JOURNAL.md index rows; %s\n", id, n[id],
                "past its third entry a row is split (rule 30)" }' \
        JOURNAL.md | sort
fi

# 17. Prior art before the first spike (rule 31): a note when a spike's RUN.md or RESULTS.md is
# not yet in HEAD (the commit that adds it) while DESIGN section 1 has no `Searches:` line
# (2.16.0: an adopter ran five spikes before finding the closest tool its first search named).
if [ -f DESIGN.md ] && grep -q '^## 1\.' DESIGN.md \
        && ! awk '/^## 1\./ { on = 1; next } /^## / { on = 0 }
                  on && /^[-* ]*(\*\*)?Searches:/ { found = 1 } END { exit !found }' DESIGN.md; then
    for f in spikes/*/RUN.md spikes/*/RESULTS.md; do
        [ -f "$f" ] || continue
        [ "$in_git" -eq 1 ] && git cat-file -e "HEAD:$f" 2>/dev/null && continue
        printf 'check: note: %s is new and DESIGN section 1 has no Searches: line; %s\n' "$f" \
            'search for the closest tool and read it before the first spike (rule 31)'
        break
    done
fi

# 18. `waits on` in a TASKS status cell (rule 30; 2.17.0, research_task_kanban_organization's
# request): `waits on <id>[, <id>...]`, each id `T-nnn`, `<repo>:T-nnn` or `H-n`, names what must
# be done before the row can start. Fails: a T-nnn that is no row here, a cycle, an H-n that
# TODO_human.md never held (a deleted H-n is done, rule 21). Notes: every target done (the row is
# ready), a `<repo>:T-nnn` whose ../<repo>/TASKS.md is missing, a cell no tool can read (old prose
# such as `waits on Q-7` stays legal).
if [ -f TASKS.md ] && grep -qE '^[|] *T-[0-9]+ *[|] *waits on' TASKS.md; then
    h_now=$([ -f TODO_human.md ] && grep -o '[*][*]H-[0-9]*[*][*]' TODO_human.md | tr -d '*' | tr '\n' ' ')
    h_ever=$([ "$in_git" -eq 1 ] && git log -p --format= -- TODO_human.md 2>/dev/null \
        | grep -o '[*][*]H-[0-9]*[*][*]' | tr -d '*' | sort -u | tr '\n' ' ')
    res=$(awk -F'|' -v h_now=" $h_now " -v h_ever=" $h_now $h_ever " '
        function sib(repo, id,    f, line, a, s, st, r) {
            f = "../" repo "/TASKS.md"; st = "norow"
            r = (getline line < f); if (r < 0) return "missing"
            while (r > 0) {
                split(line, a, "|"); s = a[2]; gsub(/ /, "", s)
                if (s == id) { st = a[3]; sub(/^ +/, "", st); break }
                r = (getline line < f)
            }
            close(f); return st
        }
        function reach(from, target, depth,    n, k, a) {
            if (depth > 500) return 0
            n = split(adj[from], a, " ")
            for (k = 1; k <= n; k++) {
                if (a[k] == target) return 1
                if (!(a[k] in seen)) { seen[a[k]] = 1; if (reach(a[k], target, depth + 1)) return 1 }
            }
            return 0
        }
        $2 ~ /^ *T-[0-9]+ *$/ {
            id = $2; gsub(/ /, "", id); st = $3; gsub(/^ +| +$/, "", st)
            row[id] = 1; status[id] = st; if (st ~ /^waits on/) wait[id] = st
        }
        END {
            ok = "^waits on (([A-Za-z0-9_.-]+:)?T-[0-9]+|H-[0-9]+)(, (([A-Za-z0-9_.-]+:)?T-[0-9]+|H-[0-9]+))*$"
            for (id in wait) {
                st = wait[id]
                if (st !~ ok) { printf "N %s: \"%s\" names no T-nnn or H-n a tool reads\n", id, st; continue }
                n = split(substr(st, 10), t, ", "); open_ = 0; bad = 0
                for (i = 1; i <= n; i++) {
                    x = t[i]
                    if (x ~ /^H-/) {
                        if (index(h_now, " " x " ")) open_++
                        else if (!index(h_ever, " " x " ")) {
                            printf "F %s waits on %s, which TODO_human.md never held\n", id, x; bad = 1 }
                    } else if (x ~ /:/) {
                        split(x, rp, ":"); s = sib(rp[1], rp[2])
                        if (s == "missing") printf "N %s waits on %s; ../%s/TASKS.md is not here\n", id, x, rp[1]
                        else if (s == "norow") printf "N %s waits on %s, no row of ../%s/TASKS.md\n", id, x, rp[1]
                        else if (s !~ /^done/) open_++
                    } else if (!(x in row)) { printf "F %s waits on %s, which is no row of TASKS.md\n", id, x; bad = 1 }
                    else { adj[id] = adj[id] " " x; if (status[x] !~ /^done/) open_++ }
                }
                if (!bad && open_ == 0) printf "N %s waits on rows that are all done: it is ready\n", id
            }
            for (id in wait) { split("", seen); if (reach(id, id, 0))
                printf "F %s is in a cycle of waits on; one of the rows cannot wait\n", id }
        }' TASKS.md | sort)
    while IFS= read -r line; do
        case $line in
            "F "*) fail "TASKS ${line#F } (rule 30)" ;;
            "N "*) printf 'check: note: TASKS %s (rule 30)\n' "${line#N }" ;;
        esac
    done <<EOF
$res
EOF
fi

# STANDARD_SKIP validation: every entry matched at least one doc or code file above.
for s in $SKIP; do
    n=$(grep -cxF -- "$s" "$matched")
    if [ "$n" -eq 0 ]; then fail "STANDARD_SKIP names $s, which matches no file this check reads"
    else case "$s" in */) skip "$n code or doc files under $s (STANDARD_SKIP)" ;; esac; fi
done
rm -f "$matched"

[ "$rc" -eq 0 ] && echo "check: ok"
exit "$rc"
