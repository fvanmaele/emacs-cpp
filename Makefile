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

test: ## ERT: build script, then init.el loaded in batch (run `make packages` first)
	$(EMACS) -Q --batch -L scripts -L test -l test/build-packages-test.el \
		-l test/init-test.el -f ert-run-tests-batch-and-exit
