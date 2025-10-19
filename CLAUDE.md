# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Environment Setup
```bash
nix develop                    # Enter default development shell with all tools
nix develop .#go              # Go development environment
nix develop .#node            # Node.js development environment
nix develop .#terraform       # Terraform environment
nix develop .#ansible         # Ansible environment
nix develop .#nix             # Nix development tools
nix develop .#ui              # UI development (Node + testing tools)
nix develop .#zig             # Zig development environment
```

### Build and Test
```bash
make check                    # Run nix flake check (validates flake structure)
make build                    # Build all package sets
make build-scripts            # Build individual scripts only
make test                     # Run all tests
make test-shells              # Test all development shell environments
make ci-local                 # Run full CI checks locally (check + fmt + lint + build + test-shells)
```

### Format and Lint
```bash
make fmt                      # Format all code (Go, JS/TS, Python, Shell, Nix)
make lint                     # Lint all code with various tools
make quick                    # Quick cycle: fmt + lint + check
scripts/fmt                   # Direct format script execution
scripts/lint                  # Direct lint script execution
```

### Git Hooks and Pre-commit
```bash
make install-hooks            # Install pre-commit hooks
make run-hooks               # Run pre-commit hooks on all files
pre-commit run --all-files   # Manual pre-commit execution
```

### Maintenance
```bash
make update                   # Update flake inputs
make upgrade                  # Run dependency upgrade script
make tidy                     # Clean up and organize code
make clean                    # Clean build artifacts (removes result*)
```

### Individual Scripts
All scripts are available as both Nix packages and shell scripts in `./scripts/`:
- `cex` - Curl and Execute utility for running remote scripts
- `fmt` - Multi-language code formatter (Go, JS/TS, Python, Shell, Nix)
- `lint` - Multi-language linter with extensive tool support
- `tidy` - Code organization and cleanup
- `upgrade` - Dependency and tool upgrading
- `fuzz` - **Enhanced parallel fuzzing** with error handling and configurable execution
- `fuzz-go` - Go-specific fuzzing
- `license` - **Enhanced license management** with fallback header creation
- `tag` - Version tagging utility

## Architecture Overview

### Nix Flake Structure
This is a **multi-environment development flake** that provides:

1. **Stable + Unstable Mix**: Uses NixOS 25.05 stable as base with select unstable packages (Go toolchain, Zig)
2. **Multiple Dev Shells**: Specialized environments for different technology stacks (Go, Node, Terraform, etc.)
3. **Unified Tooling**: Common development scripts work across all environments
4. **Binary Cache**: Uses Cachix (oss-devnw.cachix.org) for fast builds

### Key Components

#### flake.nix
- Main entry point defining all development environments
- Imports individual Nix modules for complex packages
- Configures binary cache for faster builds
- Exports both individual scripts and package collections

#### scripts.nix
- Imports and combines all individual script definitions
- Each script is defined in its own `.nix` file (fmt.nix, lint.nix, etc.)
- Scripts are built as Nix derivations with proper dependencies

#### Development Scripts
Located in `./scripts/` directory:
- **fmt**: Multi-language formatter supporting Go (goimports, gofmt), JS/TS (prettier), Python (black), Shell (shfmt), Nix (nixfmt)
- **lint**: Comprehensive linting with golangci-lint, eslint, flake8, shellcheck, nixfmt, statix, sqlfluff
- **cex**: Downloads and executes scripts from remote repositories
- **tidy/upgrade**: Maintenance utilities for dependency management

#### Configuration Strategy
- Shared configurations stored in `./shared/` directory (referenced in CRUSH.md)
- Scripts use `CONFIG_DIR` environment variable with fallback to `./shared`
- Tools support both local configs and shared defaults

### Package Organization

#### Individual Packages
Each script is available as: `nix build .#scriptname` (e.g., `.#fmt`, `.#lint`, `.#cex`)

#### Package Collections
- `commonPackages`: Core development tools
- `goPackages`: Go development stack
- `terraformPackages`: Infrastructure tools
- `ansiblePackages`: Configuration management
- `nixPackages`: Nix development tools
- `uiPackages`: Frontend development tools
- `zigPackages`: Zig language tools

### CI/CD Integration
- Pre-commit hooks automatically installed in dev shells
- GitHub Actions workflows for comprehensive testing
- Cachix integration for binary caching
- Makefile provides local CI simulation with `make ci-local`

## Development Workflow

1. **Enter Environment**: `nix develop` or specific shell (`.#go`, `.#node`, etc.)
2. **Install Hooks**: `make install-hooks` (first time only)
3. **Development Cycle**: `make quick` (format, lint, check)
4. **Full Validation**: `make ci-local` before committing
5. **Commit**: Pre-commit hooks run automatically

## Enhanced Scripts

### Fuzz Script
The `fuzz` script has been significantly enhanced with:
- **Parallel execution** across multiple CPU cores
- **Error handling** with file output and stderr tee
- **Continue-on-failure** option for comprehensive testing
- **Configurable timing** and job control
- **Progress tracking** with real-time status updates

See [FUZZ.md](./FUZZ.md) for comprehensive documentation.

### License Script
The `license` script now handles missing LICENSE files gracefully:
- **Automatic fallback** to create default headers when LICENSE_HEADER is missing
- **Multi-location search** for LICENSE and LICENSE_HEADER files
- **Git repository detection** for license file discovery
- **Comprehensive error handling** with detailed reporting
- **Help system** with usage examples

## Important Notes

- This repository focuses on **development environment tooling** rather than application code
- The `test_dir/` contains sample files for testing the development tools
- All environments include the custom scripts as part of their PATH
- Binary cache significantly speeds up initial setup and CI/CD
- Scripts are designed to work with or without configuration files
- Enhanced scripts (`fuzz`, `license`) provide production-ready capabilities with robust error handling
