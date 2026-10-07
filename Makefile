# Written by `make adopt` of llm_vibecoding_standard. Bare `make` prints help.
.DEFAULT_GOAL := help
include standard.mk

.PHONY: help
help: ## list targets (default; builds nothing)
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{ printf "  %-8s %s\n", $$1, $$2 }'
