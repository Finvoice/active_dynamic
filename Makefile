BUNDLE_EXEC := bundle exec

.DEFAULT_GOAL := help

# Show this help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-26s\033[0m %s\n", $$1, $$2}'

# Run the RSpec suite
spec: ## Run the RSpec test suite
	$(BUNDLE_EXEC) rspec

test: spec ## Alias for spec

# Run Rubocop
rubocop: ## Run RuboCop
	$(BUNDLE_EXEC) rubocop

# Run Rubocop with SAFE auto-correct only (-a). Prefer this over -A: unsafe
# corrections can change behavior (e.g. Style/SafeNavigation turns `x && x.y`
# into `x&.y`, which differs when x is false).
rubocop-auto-correct: ## Run RuboCop with safe auto-correct only (-a)
	$(BUNDLE_EXEC) rubocop -a

# Run Rubocop with UNSAFE auto-correct (-A). Review every change before committing.
rubocop-auto-correct-unsafe: ## Run RuboCop with unsafe auto-correct (-A) — review changes
	$(BUNDLE_EXEC) rubocop -A

# Regenerate .rubocop_todo.yml to grandfather existing offenses (run after a safe
# auto-correct pass to ignore the remainder that should be fixed later).
rubocop-update-todos: ## Regenerate .rubocop_todo.yml
	$(BUNDLE_EXEC) rubocop --auto-gen-config --auto-gen-only-exclude --exclude-limit 9999999

# Runs all linters
lint: rubocop ## Run all linters

.PHONY: help spec test rubocop rubocop-auto-correct rubocop-auto-correct-unsafe rubocop-update-todos lint
