.PHONY: test lint format clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

test: ## Run tests
	nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/ {minimal_init = 'test/minimal_init.lua'}"

lint: ## Run linter
	luacheck lua/ --config .luacheckrc

format: ## Format code
	@echo "Please use stylua or your preferred Lua formatter"

clean: ## Clean cache and temporary files
	rm -rf .cache/
	find . -name "*.swp" -o -name "*.swo" -o -name "*~" | xargs rm -f

doc: ## Generate documentation tags
	nvim --headless -c "helptags doc" -c "quit"