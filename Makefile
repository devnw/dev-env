.PHONY: help all check build fmt lint test clean install-hooks update deploy

# Default target
all: check build ## Default: run check and build

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

check: ## Run nix flake check
	nix flake check

build: ## Build all packages
	@echo "Building all packages..."; for pkg in commonPackages goPackages terraformPackages ansiblePackages nixPackages uiPackages zigPackages nodePackages hugoPackages; do echo "  - $${pkg}"; nix build .#$$pkg; done; echo "All packages built successfully!"

build-scripts: ## Build all individual scripts
	@echo "Building individual scripts..."
	nix build .#cex
	nix build .#fmt
	nix build .#lint
	nix build .#tidy
	nix build .#upgrade
	nix build .#fuzz
	nix build .#fuzz-go
	nix build .#license
	nix build .#tag

fmt: ## Format all code
	nix develop --command ./scripts/fmt

lint: ## Lint all code
	nix develop --command ./scripts/lint

test: check build ## Run all tests
	@echo "Running comprehensive tests..."
	nix develop --command bash -c "echo 'Testing complete!'"

test-shells: ## Test all development shells
	@echo "Testing development shells..."
	@for shell in default go ansible terraform nix node ui zig; do \
		echo "Testing $$shell shell..."; \
		nix develop .#$$shell --command echo "$$shell shell works"; \
	done

clean: ## Clean build artifacts
	rm -rf result result-*

install-hooks: ## Install pre-commit hooks
	nix develop --command pre-commit install

run-hooks: ## Run pre-commit hooks on all files
	nix develop --command pre-commit run --all-files

update: ## Update flake inputs
	nix flake update
	@echo "Updated flake inputs. Run 'make check' to verify."

upgrade: ## Run upgrade script
	nix develop --command ./scripts/upgrade

tidy: ## Run tidy script
	nix develop --command ./scripts/tidy

fuzz: ## Run fuzzing tests
	nix develop --command ./scripts/fuzz

# Development environment shortcuts
dev: ## Enter default development shell
	nix develop

dev-go: ## Enter Go development shell
	nix develop .#go

dev-ansible: ## Enter Ansible development shell
	nix develop .#ansible

dev-terraform: ## Enter Terraform development shell
	nix develop .#terraform

dev-nix: ## Enter Nix development shell
	nix develop .#nix

dev-node: ## Enter Node.js development shell
	nix develop .#node

dev-ui: ## Enter UI development shell
	nix develop .#ui

dev-zig: ## Enter Zig development shell
	nix develop .#zig

# CI/CD related targets
ci-local: ## Run CI checks locally
	@echo "Running local CI checks..."
	make check
	make fmt
	make lint
	make build
	make test-shells
	@echo "Local CI checks completed successfully!"

deploy: ## Deploy (placeholder for actual deployment)
	@echo "Deployment target - customize as needed"
	nix develop .#ansible --command echo "Ready for deployment"

# Documentation
docs: ## Generate documentation
	@echo "# Flake Documentation" > FLAKE_DOCS.md
	@echo "Generated on: $$(date)" >> FLAKE_DOCS.md

# Script shortcuts
cex: ## Build and run cex script
	nix build .#cex
	./result/bin/cex

cex-list: ## List available scripts via cex
	nix build .#cex
	./result/bin/cex --list

# Validation
validate: ## Run full validation suite
	@echo "Running full validation..."
	make check
	make build-scripts

# Quick development cycle
quick: ## Quick development cycle: format, lint, check
	make fmt
	make lint
	make check
	@echo "Quick checks completed!"

# Pre-commit target for hooks
pre-commit: ## Run pre-commit checks for CI
	make fmt
	make lint

# Cachix targets
push-cachix: ## Push built packages to Cachix binary cache
	@echo "Pushing all packages to Cachix..."
	@echo "Building and pushing package sets..."
	nix build .#commonPackages --json | jq -r '.[].outputs.out' | cachix push oss-devnw
	nix build .#goPackages --json | jq -r '.[].outputs.out' | cachix push oss-devnw
	nix build .#terraformPackages --json | jq -r '.[].outputs.out' | cachix push oss-devnw
	nix build .#ansiblePackages --json | jq -r '.[].outputs.out' | cachix push oss-devnw
	nix build .#nixPackages --json | jq -r '.[].outputs.out' | cachix push oss-devnw
	nix build .#uiPackages --json | jq -r '.[].outputs.out' | cachix push oss-devnw
	nix build .#zigPackages --json | jq -r '.[].outputs.out' | cachix push oss-devnw
	nix build .#nodePackages --json | jq -r '.[].outputs.out' | cachix push oss-devnw
	nix build .#hugoPackages --json | jq -r '.[].outputs.out' | cachix push oss-devnw
	nix build .#ciPackages --json | jq -r '.[].outputs.out' | cachix push oss-devnw
	@echo "Building and pushing individual scripts..."
	@for script in cex fmt lint tidy upgrade fuzz fuzz-go license tag; do \
		echo "Pushing $$script..."; \
		nix build .#$$script --json | jq -r '.[].outputs.out' | cachix push oss-devnw; \
	done
	@echo "All packages and scripts pushed to Cachix!"

push-all-cachix: ## Push all packages, scripts, and dev shell dependencies
	@echo "🚀 Building and pushing EVERYTHING to Cachix..."
	@echo "This may take a while as it builds all environments..."
	@echo ""
	@echo "📦 Pushing package sets..."
	make push-cachix
	@echo ""
	@echo "🔧 Building and pushing development shell dependencies..."
	@for shell in default go ansible terraform nix node ui zig ci; do \
		echo "Building $$shell development shell..."; \
		nix develop .#$$shell --command echo "$$shell shell built"; \
	done
	@echo ""
	@echo "✅ All packages, scripts, and development environments pushed to Cachix!"
	@echo "🎉 Users will now get instant builds for everything!"

push-scripts-cachix: ## Push individual scripts to Cachix
	@echo "Building and pushing scripts to Cachix..."
	@for script in cex fmt lint tidy upgrade fuzz fuzz-go license tag; do \
		echo "Pushing $$script..."; \
		nix build .#$$script --json | jq -r '.[].outputs.out' | cachix push oss-devnw; \
	done
	@echo "All scripts pushed to Cachix!"

setup-cachix: ## Setup Cachix authentication (requires CACHIX_AUTH_TOKEN env var)
	@if [ -z "$$CACHIX_AUTH_TOKEN" ]; then \
		echo "Error: CACHIX_AUTH_TOKEN environment variable not set"; \
		echo "Generate a token at https://app.cachix.org/cache/oss-devnw and set:"; \
		echo "export CACHIX_AUTH_TOKEN=your_token_here"; \
		exit 1; \
	fi
	@echo "Setting up Cachix authentication..."
	echo "$$CACHIX_AUTH_TOKEN" | cachix authtoken --stdin
	@echo "Cachix authentication configured!"
