# CRUSH.md - Development Environment Commands & Style Guide

## Build/Test/Lint Commands
```bash
# Development shells
nix develop              # Enter default dev shell with all tools
nix develop .#go         # Go development shell  
nix develop .#node       # Node.js development shell
nix develop .#terraform  # Terraform development shell

# Build & Check
make build               # Build all packages
make check               # Run nix flake check
make test                # Run all tests
make ci-local            # Run full CI checks locally
go test ./...            # Run all Go tests
go test -v -run TestName ./pkg/...  # Run single Go test

# Format & Lint
make fmt                 # Format all code (runs scripts/fmt)
make lint                # Lint all code (runs scripts/lint)
make quick               # Quick cycle: fmt, lint, check
golangci-lint run --fix --config shared/.golangci.yml  # Fix Go issues
prettier --write .       # Format JS/TS/JSON/YAML files
nixfmt flake.nix        # Format Nix files

# Pre-commit & Git hooks
make install-hooks       # Install pre-commit hooks
make run-hooks          # Run hooks on all files
pre-commit run --all-files  # Manual hook run
```

## Code Style Guidelines
- **Go**: Use goimports + gofmt, follow shared/.golangci.yml rules, errors must be handled
- **Imports**: Group by stdlib → external → internal (goimports-reviser auto-formats)
- **Naming**: Go (camelCase), Python (snake_case), SQL (snake_case), constants (UPPER_SNAKE)
- **Error handling**: Check all errors, wrap with fmt.Errorf("context: %w", err)
- **Testing**: Table-driven tests, parallel where possible, mock external deps
- **Nix**: Use nixfmt-rfc-style, pure functions, descriptive attribute names
- **Config**: Shared configs in ./shared/ dir (.golangci.yml, .prettierrc.yaml, etc.)
- **Pre-commit**: Runs fmt on commit, lint on push, commitizen validates messages
