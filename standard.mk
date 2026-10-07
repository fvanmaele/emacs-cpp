# standard.mk - llm_vibecoding_standard targets. `include standard.mk` from the project
# Makefile. Sets no default goal: the project's own `help` stays the default.
.PHONY: check
check: ## docs consistency per llm_vibecoding_standard (fails loudly)
	@sh scripts/check-standard.sh
