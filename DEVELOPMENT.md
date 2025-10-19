# Development Workflow and CI/CD

This document describes the development workflow, pre-commit hooks, and CI/CD pipeline for this repository.

## Pre-commit Hooks

We use pre-commit hooks to ensure code quality and consistency. The hooks are automatically installed when you enter the development shell.

### Setup

1. Enter the development shell:

   ```bash
   nix develop
   ```

2. Install pre-commit hooks:

   ```bash
   make install-hooks
   # or manually:
   pre-commit install
   ```

### Running Hooks

Pre-commit hooks run automatically on `git commit`. You can also run them manually:

```bash
# Run on all files
make run-hooks
# or
pre-commit run --all-files

# Run on staged files only
pre-commit run
```

### Configured Hooks

- **Nix formatting**: `nixpkgs-fmt` for consistent Nix code formatting
- **Shell linting**: `shellcheck` for shell script quality
- **Shell formatting**: `shfmt` for consistent shell script formatting
- **Python formatting**: `black` for Python code formatting
- **Python linting**: `flake8` for Python code quality
- **General checks**: trailing whitespace, end-of-file, YAML/JSON validation
- **Custom checks**: Our own `fmt.sh` and `lint.sh` scripts

## Development Scripts

All development scripts are available as Nix packages and in the development shell:

### Available Scripts

- **`cex`**: Curl and Execute scripts from shared repository
- **`fmt`**: Format code files (Go, JS/TS, Python, Shell, Nix)
- **`lint`**: Lint code files (Go, JS/TS, Python, Shell, Nix)
- **`tidy`**: Clean up and organize code
- **`upgrade`**: Upgrade dependencies and tools
- **`fuzz`**: Run fuzzing tests

### Usage

```bash
# Enter development shell
nix develop

# List available scripts
cex --list

# Format all code
fmt.sh
# or
make fmt

# Lint all code
lint.sh
# or
make lint

# Run comprehensive checks
make quick  # format + lint + flake check
make validate  # full validation suite
```

## Makefile Targets

We provide a comprehensive Makefile for common development tasks:

```bash
make help           # Show available targets
make check          # Run nix flake check
make build          # Build all packages
make fmt            # Format all code
make lint           # Lint all code
make test           # Run all tests
make clean          # Clean build artifacts
make install-hooks  # Install pre-commit hooks
make update         # Update flake inputs
make ci-local       # Run CI checks locally
make validate       # Run full validation suite
```

## CI/CD Pipeline

### GitHub Workflows

We have several workflows for comprehensive CI/CD:

#### 1. CI/CD Pipeline (`.github/workflows/ci.yml`)

Runs on every push and pull request:

- **Nix Flake Checks**: Validates flake syntax and structure
- **Build Scripts**: Builds all individual scripts and tests basic functionality
- **Test Dev Shells**: Validates all development shell environments
- **Lint and Format**: Ensures code quality and consistency
- **Pre-commit Checks**: Runs all pre-commit hooks
- **Security Checks**: Scans for vulnerabilities
- **Package Sets**: Builds all package combinations
- **Final Validation**: Comprehensive validation and reporting
- **Cachix Integration**: Automatically pushes built packages to binary cache

#### 2. Maintenance Workflow (`.github/workflows/maintenance.yml`)

Runs weekly and on-demand:

- **Update Flake Inputs**: Automatically updates dependencies
- **Security Audit**: Regular vulnerability scanning
- **Lint Scripts**: Comprehensive script validation
- **Test Package Builds**: Ensures all packages build correctly
- **Generate Documentation**: Auto-generates documentation
- **Cachix Push**: Pushes updated packages to cache

#### 3. Cachix Binary Cache (`.github/workflows/cachix.yml`)

Runs daily and on main branch pushes:

- **Build All Packages**: Builds every script and package set
- **Build Dev Shells**: Ensures all development environments are cached
- **Push to Cachix**: Uploads all builds to the binary cache for faster access

#### 4. Push to Cachix (`.github/workflows/push-cachix.yml`)

Runs on every push to main when relevant files change:

- **Automatic Pushing**: Builds and pushes all packages immediately on changes
- **Smart Triggers**: Only runs when flake files or scripts are modified
- **Validation**: Tests that pushed packages are available from cache
- **Summary Reports**: Provides detailed success summaries

## Binary Cache (Cachix)

We use Cachix to provide pre-built packages for faster development and CI/CD.

### For Users

The cache is automatically configured in `flake.nix`. Users get faster builds automatically:

```bash
# These commands will use cached builds when available
nix develop
nix build .#cex
nix shell github:devnw/flakes#fmt
```

### For Contributors

#### Setup Cachix Authentication

1. Get an auth token from [Cachix](https://app.cachix.org/cache/oss-devnw)
2. Set up authentication:

```bash
export CACHIX_AUTH_TOKEN=your_token_here
make setup-cachix
```

#### Push to Cache

```bash
# Push all packages and scripts (recommended)
make push-cachix

# Push everything including dev shell dependencies (comprehensive)
make push-all-cachix

# Push individual scripts only
make push-scripts-cachix

# Manual push
nix build .#cex | cachix push oss-devnw
```

#### GitHub Actions Setup

For the CI/CD pipeline to push to Cachix, set the `CACHIX_AUTH_TOKEN` secret in your repository settings.

- **Test Dev Shells**: Validates all development shell environments
- **Lint and Format**: Ensures code quality and consistency
- **Pre-commit Checks**: Runs all pre-commit hooks
- **Security Checks**: Scans for vulnerabilities
- **Package Sets**: Builds all package combinations
- **Final Validation**: Comprehensive validation and reporting

#### 2. Maintenance (`.github/workflows/maintenance.yml`)

Runs weekly and on-demand:

- **Update Flake Inputs**: Automatically updates dependencies
- **Security Audit**: Regular vulnerability scanning
- **Lint Scripts**: Comprehensive script validation
- **Test Package Builds**: Ensures all packages build correctly
- **Generate Documentation**: Auto-generates documentation

### Local Development

Before pushing changes, run local CI checks:

```bash
make ci-local
```

This will run the same checks as the CI pipeline locally.

## Development Environments

Multiple specialized development environments are available:

```bash
nix develop          # Default (full environment)
nix develop .#go     # Go development
nix develop .#ansible # Ansible environment
nix develop .#terraform # Terraform environment
nix develop .#nix    # Nix development
nix develop .#node   # Node.js environment
nix develop .#ui     # UI development
nix develop .#zig    # Zig development
```

Each environment includes:

- Common tools (git, curl, editors, etc.)
- Linting tools (shellcheck, yamllint, etc.)
- Environment-specific tools
- All custom scripts

## Quality Assurance

### Automated Checks

1. **Pre-commit hooks** catch issues before commit
2. **CI pipeline** validates every change
3. **Security scanning** identifies vulnerabilities
4. **Dependency updates** keep packages current

### Manual Testing

```bash
# Quick development cycle
make quick

# Full validation
make validate

# Test specific functionality
make build-scripts
make test-shells
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Run `make ci-local` to validate
5. Commit (pre-commit hooks will run)
6. Push and create a pull request

The CI pipeline will automatically validate your changes and provide feedback.

## Troubleshooting

### Pre-commit Issues

If pre-commit hooks fail:

```bash
# Check what failed
pre-commit run --all-files

# Fix formatting issues
make fmt

# Fix linting issues
make lint

# Re-run checks
make run-hooks
```

### Build Issues

If builds fail:

```bash
# Clean and rebuild
make clean
make build

# Check flake syntax
make check

# Update dependencies
make update
```

### Environment Issues

If development shell has issues:

```bash
# Test specific shell
nix develop .#go --command echo "test"

# Rebuild shell
nix develop --refresh

# Check for conflicts
nix flake check
```
