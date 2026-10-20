# SPDX-License-Identifier: GPL-3.0-or-later
# standard.mk - llm_vibecoding_standard targets. `include standard.mk` from the project
# Makefile. Sets no default goal: the project's own `help` stays the default. The target
# is `docs-check`, not `check`: it reads docs only and finishes in under a second. Chain it
# into your own `verify` if you like; never chain code checks into it.
# STANDARD_SKIP: fork only - upstream-owned docs the check never reads (README section
# "Adopting in a FORK"). STANDARD_WIDTH: prose width limit, default 128, 0 = off.
# STANDARD_TYPOGRAPHY: note (default) or fail; fail turns dashes, smart quotes, ellipsis and
# emoji in docs into failures, fenced code blocks exempt. STANDARD_COMMIT_EMAIL: public
# projects only, their commit address; `make hook` then refuses a commit from another address
# or outside UTC. STANDARD_CODE_UNICODE: code files
# that must keep their non-ASCII: localized UI text, a real-data test fixture, a file the repo
# never edits such as an applied migration (each backed by a D-row); they skip the ASCII pass.
# STANDARD_TIER1_FILES / _LINES: rule 15 bound for `Tier: 1` commits (commit-msg hook).
# STANDARD_FORK_BASE: forks only, a git ref; the code-ASCII pass reads lines added since it.
STANDARD_SKIP ?=
STANDARD_WIDTH ?= 128
STANDARD_TYPOGRAPHY ?= note
STANDARD_CODE_UNICODE ?=
STANDARD_COMMIT_EMAIL ?=
STANDARD_FORK_BASE ?=
STANDARD_TIER1_FILES ?= 3
STANDARD_TIER1_LINES ?= 50
.PHONY: docs-check hook
docs-check: ## docs consistency per llm_vibecoding_standard; docs only, fails loudly
	@STANDARD_SKIP='$(STANDARD_SKIP)' STANDARD_WIDTH='$(STANDARD_WIDTH)' STANDARD_TYPOGRAPHY='$(STANDARD_TYPOGRAPHY)' \
		STANDARD_CODE_UNICODE='$(STANDARD_CODE_UNICODE)' STANDARD_FORK_BASE='$(STANDARD_FORK_BASE)' \
		sh scripts/check-standard.sh

hook: ## install pre-commit (docs-check) and commit-msg (tier 1 bound) hooks; refuses if one exists
	@git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "hook: not a git work tree" >&2; exit 1; }
	@hooks=$$(git rev-parse --git-path hooks); sub=./$$(git rev-parse --show-prefix); mkdir -p "$$hooks"; \
	for h in pre-commit commit-msg; do test ! -e "$$hooks/$$h" \
		|| { echo "hook: $$hooks/$$h exists, merge by hand (scripts/check-standard.sh, scripts/commit-msg.sh)" >&2; \
		     exit 1; }; done; \
	fix='case "$${GIT_INDEX_FILE:-/}" in /*) ;; *) GIT_INDEX_FILE=$$PWD/$$GIT_INDEX_FILE; export GIT_INDEX_FILE ;; esac'; \
	printf '#!/bin/sh\n# llm_vibecoding_standard docs-check (installed by make hook); git runs hooks from the repo root\n%s\n' \
		"$$fix" > "$$hooks/pre-commit"; \
	if [ -n '$(STANDARD_COMMIT_EMAIL)' ]; then \
		printf '[ "$$(git config user.email)" = "%s" ] || { echo "pre-commit: commit as %s" >&2; exit 1; }\n' \
			'$(STANDARD_COMMIT_EMAIL)' '$(STANDARD_COMMIT_EMAIL)' >> "$$hooks/pre-commit"; \
		printf '[ "$$(date +%%z)" = "+0000" ] || { echo "pre-commit: commit with TZ=UTC" >&2; exit 1; }\n' \
			>> "$$hooks/pre-commit"; \
	fi; \
	printf "[ -f '%sscripts/check-standard.sh' ] || exit 0\n" "$$sub" >> "$$hooks/pre-commit"; \
	printf "cd '%s' && STANDARD_SKIP='%s' STANDARD_WIDTH='%s' STANDARD_TYPOGRAPHY='%s' %s='%s' STANDARD_FORK_BASE='%s' %s\n" \
		"$$sub" '$(STANDARD_SKIP)' '$(STANDARD_WIDTH)' '$(STANDARD_TYPOGRAPHY)' STANDARD_CODE_UNICODE \
		'$(STANDARD_CODE_UNICODE)' '$(STANDARD_FORK_BASE)' 'exec sh scripts/check-standard.sh' >> "$$hooks/pre-commit"; \
	printf '#!/bin/sh\n# llm_vibecoding_standard tier 1 bound (installed by make hook)\n%s\n' "$$fix" > "$$hooks/commit-msg"; \
	printf "[ -f '%sscripts/commit-msg.sh' ] || exit 0\n" "$$sub" >> "$$hooks/commit-msg"; \
	printf 'case "$$1" in /*) msg=$$1 ;; *) msg=$$PWD/$$1 ;; esac\n' >> "$$hooks/commit-msg"; \
	printf "cd '%s' && STANDARD_TIER1_FILES='%s' STANDARD_TIER1_LINES='%s' exec sh scripts/commit-msg.sh \"\$$msg\"\n" \
		"$$sub" '$(STANDARD_TIER1_FILES)' '$(STANDARD_TIER1_LINES)' >> "$$hooks/commit-msg"; \
	chmod +x "$$hooks/pre-commit" "$$hooks/commit-msg" && echo "hook: installed pre-commit and commit-msg in $$hooks"
