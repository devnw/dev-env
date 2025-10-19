# Generic Makefile for Go projects
# Copy this file to your project root as 'Makefile' and customize variables as needed

#-------------------------------------------------------------------------
# Project Configuration - Customize these variables
#-------------------------------------------------------------------------

# Project name (defaults to directory name)
PROJECT_NAME ?= $(shell basename $(CURDIR))

# Go module path (auto-detected from go.mod or use PROJECT_NAME)
MODULE_PATH ?= $(shell go list -m 2>/dev/null || echo "$(PROJECT_NAME)")

# Build environment variables
BUILD_ENV ?= CGO_ENABLED=1

# Go version constraint (optional)
GO_VERSION ?= 1.21

# Output directories
OUT_DIR ?= out
DIST_DIR ?= dist

# Remote script repository for shared tooling
SHARED_FILES_URL ?= https://raw.githubusercontent.com/devnw/flakes/refs/heads/main

# Test configuration
TEST_FLAGS ?= -v -cover -failfast -race
TEST_TIMEOUT ?= 10m
FUZZ_TIME ?= 30s

# Coverage configuration  
COVERAGE_FILE ?= $(OUT_DIR)/coverage.txt
COVERAGE_MODE ?= atomic
COVERAGE_THRESHOLD ?= 80

# Benchmark configuration
BENCH_FLAGS ?= -bench=. -benchmem
BENCH_OUTPUT ?= $(OUT_DIR)/bench-output.txt

# Release configuration
RELEASE_FLAGS ?= --clean
DEV_RELEASE_FLAGS ?= $(RELEASE_FLAGS) --snapshot

#-------------------------------------------------------------------------
# Shell Configuration
#-------------------------------------------------------------------------

# Use bash for all shell commands
SHELL := $(shell which bash)
.SHELLFLAGS := -eu -o pipefail -c

# Make variables available to sub-processes
.EXPORT_ALL_VARIABLES:

#-------------------------------------------------------------------------
# Default Target
#-------------------------------------------------------------------------

all: deps build test

#-------------------------------------------------------------------------
# Development Targets
#-------------------------------------------------------------------------

# Set up development dependencies
deps:
	@echo "Setting up dependencies..."
	@mkdir -p $(OUT_DIR) $(DIST_DIR)
	@go version
	@echo "Project: $(PROJECT_NAME)"
	@echo "Module: $(MODULE_PATH)"

# Pre-commit hook target
pre-commit: deps upgrade tidy fmt lint build test

# Run tests with coverage
test: deps
	@echo "Running tests..."
	$(BUILD_ENV) go test $(TEST_FLAGS) -timeout $(TEST_TIMEOUT) ./...

# Run tests with detailed coverage output
test-coverage: deps
	@echo "Running tests with coverage..."
	$(BUILD_ENV) go test \
		-cover \
		-covermode=$(COVERAGE_MODE) \
		-coverprofile=$(COVERAGE_FILE) \
		$(TEST_FLAGS) \
		-timeout $(TEST_TIMEOUT) ./...
	@go tool cover -html=$(COVERAGE_FILE) -o $(OUT_DIR)/coverage.html
	@echo "Coverage report: $(OUT_DIR)/coverage.html"

# Check coverage threshold
coverage-check: test-coverage
	@echo "Checking coverage threshold ($(COVERAGE_THRESHOLD)%)..."
	@go tool cover -func=$(COVERAGE_FILE) | grep "total:" | awk '{if ($$3+0 < $(COVERAGE_THRESHOLD)) {print "Coverage " $$3 " is below threshold $(COVERAGE_THRESHOLD)%"; exit 1} else {print "Coverage " $$3 " meets threshold $(COVERAGE_THRESHOLD)%"}}'

# Run fuzz tests
fuzz: deps
	@echo "Running fuzz tests..."
	@FUZZ_TIME=$(FUZZ_TIME) FUZZ_CONTINUE_ON_FAILURE=true fuzz

# Run benchmarks
bench: deps
	@echo "Running benchmarks..."
	go test $(BENCH_FLAGS) ./... | tee $(BENCH_OUTPUT)

# Run all tests (unit + fuzz + bench)
test-all: test fuzz bench

# Format code
fmt:
	@echo "Formatting code..." || fmt

# Lint code
lint:
	@echo "Linting code..." || lint

# Tidy go modules
tidy: fmt
	@echo "Tidying go modules..." || tidy

# Verify go.mod is tidy
go.mod: tidy

# Build the project
build: go.mod fmt lint
	@echo "Building project..."
	$(BUILD_ENV) go build ./...

# Build with race detection
build-race: go.mod fmt lint
	@echo "Building with race detection..."
	$(BUILD_ENV) go build -race ./...

# Install project binaries
install: build
	@echo "Installing binaries..."
	$(BUILD_ENV) go install ./...

#-------------------------------------------------------------------------
# Release Targets
#-------------------------------------------------------------------------

# Development release (snapshot)
release-dev: deps build test-coverage
	@echo "Creating development release..."
	$(BUILD_ENV) goreleaser release $(DEV_RELEASE_FLAGS)

# Production release
release-prod: deps test-coverage bench
	@echo "Creating production release..."
	$(BUILD_ENV) goreleaser release $(RELEASE_FLAGS)

# Create and push git tag
tag:
	@if [ -z "$(TAG)" ]; then echo "Usage: make tag TAG=v1.0.0"; exit 1; fi
	@echo "Creating tag $(TAG)..."
	git tag -a $(TAG) -m "Release $(TAG)"
	git push origin $(TAG)

#-------------------------------------------------------------------------
# Maintenance Targets
#-------------------------------------------------------------------------

# Upgrade dependencies and tools
upgrade:
	@echo "Upgrading dependencies..." || upgrade

# Update git submodules
update:
	@echo "Updating submodules..."
	git submodule update --recursive --remote

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(DIST_DIR) $(OUT_DIR)
	go clean -cache -testcache -modcache

# Clean and reset everything
reset: clean
	@echo "Resetting workspace..."
	git clean -fdx
	git submodule foreach --recursive git clean -fdx

#-------------------------------------------------------------------------
# CI/CD Targets
#-------------------------------------------------------------------------

# CI build target
build-ci: lint
	@echo "Building for CI..."
	$(BUILD_ENV) go build ./...

# CI test target
test-ci: deps build-ci
	@echo "Running CI tests..."
	$(BUILD_ENV) go test \
		-cover \
		-covermode=$(COVERAGE_MODE) \
		-coverprofile=$(COVERAGE_FILE) \
		-failfast \
		-race \
		-timeout $(TEST_TIMEOUT) ./...
	@make fuzz FUZZ_TIME=10s

# CI benchmark target
bench-ci: deps test-ci
	@echo "Running CI benchmarks..."
	go test $(BENCH_FLAGS) ./... | tee $(BENCH_OUTPUT)

# CI release target
release-ci: bench-ci coverage-check
	@echo "Running CI release..."
	$(BUILD_ENV) goreleaser release $(RELEASE_FLAGS)

#-------------------------------------------------------------------------
# Development Helpers
#-------------------------------------------------------------------------

# Watch for changes and run tests
watch:
	@command -v fswatch >/dev/null 2>&1 || { echo "fswatch not installed. Install with: brew install fswatch"; exit 1; }
	@echo "Watching for changes..."
	fswatch -o . -e "$(OUT_DIR)" -e "$(DIST_DIR)" -e ".git" | xargs -n1 -I{} make test

# Run development server (if applicable)
dev:
	@echo "Starting development server..."
	@[ -f "main.go" ] && go run main.go || \
	[ -f "cmd/$(PROJECT_NAME)/main.go" ] && go run cmd/$(PROJECT_NAME)/main.go || \
	echo "No main.go found. Customize this target for your project."

# Show project information
info:
	@echo "Project: $(PROJECT_NAME) ($(MODULE_PATH))"
	@echo "Go: $(shell go version)"
	@echo "Build: $(BUILD_ENV)"
	@echo "Dirs: $(OUT_DIR), $(DIST_DIR)"
	@echo "Coverage: $(COVERAGE_FILE) ($(COVERAGE_MODE))"

# Show available targets
help:
	@echo "Dev: all, deps, build, test, test-coverage, fuzz, bench"
	@echo "Quality: fmt, lint, tidy, watch"
	@echo "Release: release-dev, release-prod, tag TAG=version"
	@echo "Maintenance: upgrade, update, clean, reset"
	@echo "CI/CD: build-ci, test-ci, bench-ci, release-ci"

#-------------------------------------------------------------------------
# Phony targets
#-------------------------------------------------------------------------

.PHONY: all deps pre-commit test test-coverage coverage-check fuzz bench test-all fmt lint tidy go.mod build build-race install release-dev release-prod tag upgrade update clean reset build-ci test-ci bench-ci release-ci watch dev info help FORCE

#-------------------------------------------------------------------------
# Force targets
#-------------------------------------------------------------------------

FORCE:
