# Generic Go Project Makefile

This repository includes a generic, reusable Makefile for Go projects that provides consistent build, test, and deployment workflows.

## Features

- **Standardized workflow**: Consistent targets across all Go projects
- **Configurable**: Easy customization through variables
- **CI/CD ready**: Separate targets for continuous integration
- **Comprehensive**: Covers development, testing, building, and releasing
- **Remote tooling**: Uses shared scripts for consistency across projects
- **Self-documenting**: Built-in help and info targets

## Quick Setup

### Option 1: Copy Template

1. Copy `Makefile.template` to your project root as `Makefile`
2. Customize the configuration variables at the top
3. Run `make help` to see available targets

### Option 2: Download Latest

```bash
curl -fsSL https://raw.githubusercontent.com/devnw/opt/main/Makefile.template > Makefile
```

## Configuration

Customize these variables at the top of your Makefile:

```makefile
# Project Configuration
PROJECT_NAME := my-project
MODULE_PATH := github.com/user/my-project
BUILD_ENV := CGO_ENABLED=1

# Directories
OUT_DIR := out
DIST_DIR := dist

# Test configuration
TEST_FLAGS := -v -cover -failfast -race
TEST_TIMEOUT := 10m
FUZZ_TIME := 30s

# Coverage
COVERAGE_MODE := atomic
COVERAGE_THRESHOLD := 80

# Remote scripts (optional - use your own or keep default)
SHARED_SCRIPTS_URL := https://raw.githubusercontent.com/devnw/flakes/refs/heads/main/scripts
```

## Common Targets

### Development

- `make all` - Build, test, and verify project
- `make deps` - Set up development dependencies
- `make build` - Build the project
- `make test` - Run tests
- `make test-coverage` - Run tests with coverage report
- `make fmt` - Format code
- `make lint` - Lint code
- `make tidy` - Tidy go modules

### Testing

- `make test-all` - Run all tests (unit + fuzz + bench)
- `make fuzz` - Run fuzz tests
- `make bench` - Run benchmarks
- `make coverage-check` - Verify coverage meets threshold

### Release

- `make release-dev` - Create development release (snapshot)
- `make release-prod` - Create production release
- `make tag TAG=v1.0.0` - Create and push git tag

### Maintenance

- `make upgrade` - Upgrade dependencies
- `make clean` - Clean build artifacts
- `make update` - Update git submodules

### CI/CD

- `make test-ci` - CI test target with coverage
- `make build-ci` - CI build target
- `make release-ci` - CI release target

### Utilities

- `make help` - Show all available targets
- `make info` - Show project information
- `make watch` - Watch for changes and run tests (requires fswatch)

## Project Structure Assumptions

The Makefile works best with these common Go project structures:

### Simple Project

```
my-project/
├── Makefile
├── go.mod
├── go.sum
├── main.go
├── *.go
└── *_test.go
```

### Standard Layout

```
my-project/
├── Makefile
├── go.mod
├── go.sum
├── cmd/
│   └── my-project/
│       └── main.go
├── internal/
├── pkg/
└── test/
```

## Remote Scripts

The Makefile uses remote scripts for common operations:

- **fmt.sh** - Code formatting (Go, shell, markdown, etc.)
- **lint.sh** - Code linting with multiple tools
- **upgrade.sh** - Dependency upgrades (Go, npm, nix, etc.)
- **tidy.sh** - Module tidying
- **fuzz.sh** - Fuzz testing

You can:

1. Use the default shared scripts
2. Point to your own script repository
3. Replace with local scripts

### Using Local Scripts

Replace remote script calls with local equivalents:

```makefile
# Instead of remote
FMT := curl -fsSL $(SHARED_SCRIPTS_URL)/fmt.sh | $(SHELL)

# Use local
FMT := ./scripts/fmt.sh
```

## Integration with GoReleaser

The Makefile includes release targets that work with [GoReleaser](https://goreleaser.com/):

1. Install GoReleaser
2. Create `.goreleaser.yml` config
3. Use `make release-dev` or `make release-prod`

## Integration with Pre-commit

Use `make pre-commit` as your pre-commit hook:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: go-pre-commit
        name: Go pre-commit
        entry: make pre-commit
        language: system
        pass_filenames: false
```

## Customization Examples

### Custom Test Flags

```makefile
# Run tests with custom flags
TEST_FLAGS := -v -cover -failfast -race -short
```

### Multiple Build Targets

```makefile
# Add custom build targets
build-linux:
	GOOS=linux GOARCH=amd64 $(BUILD_ENV) go build -o $(OUT_DIR)/app-linux ./cmd/app

build-windows:
	GOOS=windows GOARCH=amd64 $(BUILD_ENV) go build -o $(OUT_DIR)/app.exe ./cmd/app

build-all: build build-linux build-windows
```

### Custom Development Server

```makefile
# Override the dev target
dev:
	go run cmd/server/main.go --dev --port=8080
```

### Additional Dependencies

```makefile
# Add to deps target
deps:
	@echo "Setting up dependencies..."
	@mkdir -p $(OUT_DIR) $(DIST_DIR)
	@go version
	@npm install  # If you have frontend assets
	@go install github.com/custom/tool@latest
```

## Troubleshooting

### Common Issues

1. **Remote scripts fail**: Check internet connection or use local scripts
2. **GoReleaser not found**: Install GoReleaser or remove release targets
3. **Coverage threshold not met**: Adjust `COVERAGE_THRESHOLD` or improve tests
4. **fswatch not found**: Install for `make watch` or remove target

### Debugging

Enable verbose output:

```bash
make test V=1
```

Check what commands would run:

```bash
make -n test
```

## Contributing

When contributing improvements to the generic Makefile:

1. Test with multiple project types
2. Maintain backward compatibility
3. Document new features
4. Update examples

## License

This Makefile template is provided under the same license as the project it's used in.
