# Written by `make adopt` of llm_vibecoding_standard. Bare `make` prints help.
.DEFAULT_GOAL := help
include standard.mk

.PHONY: help
help: ## list targets (default; builds nothing)
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{ printf "  %-8s %s\n", $$1, $$2 }'

EMACS ?= emacs

.PHONY: packages test
packages: ## byte-compile lib/ submodules; write lib/load-path.el, lib/autoloads.el
	$(EMACS) -Q --batch -l scripts/build-packages.el -f build-packages-batch

# make test runs in an empty temporary HOME, so no test can write to the real one
# (D-104); REAL_HOME=1 runs in yours, as a hand run of the test files does.
REAL_HOME ?=
ifeq ($(REAL_HOME),)
# Stops the run unless HOME really is another directory: `~USER' is found through
# the user database, whatever HOME says.
HOME_CHECK = --eval "(when (file-equal-p \"~\" (concat \"~\" (user-login-name))) \
	(error \"make test: HOME is the real home, %s; it should be a temporary directory (D-104)\" \
	(expand-file-name \"~\")))"
endif
# A missing grammar fails its tests instead of asking to install it on stdin.
ERT = $(EMACS) -Q --batch $(HOME_CHECK) -L scripts -L lisp -L test \
	--eval "(setq treesit-auto-install-grammar 'never)" \
	$(foreach f,$(sort $(wildcard test/*-test.el)),\
		--eval "(require '$(basename $(notdir $(f))))") \
	-f ert-run-tests-batch-and-exit

test: ## ERT in a temporary HOME; REAL_HOME=1 uses yours (run `make packages` first)
ifeq ($(REAL_HOME),)
	@home=$$(mktemp -d "$${TMPDIR:-/tmp}/emacs-cpp-test-home.XXXXXX") || exit 1; \
	trap 'rm -rf "$$home"' EXIT; trap 'exit 130' INT TERM; \
	echo "make test: HOME=$$home"; \
	HOME="$$home" $(ERT)
else
	$(ERT)
endif
