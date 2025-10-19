# Fuzz Testing Documentation

## Overview

The enhanced `fuzz` script provides parallel execution of Go fuzz tests with comprehensive error handling, logging, and configuration options. It automatically discovers all fuzz functions in your codebase and runs them concurrently for maximum efficiency.

## Features

- **Parallel Execution**: Automatically detects CPU cores and runs multiple fuzz tests concurrently
- **Error Handling**: Comprehensive error logging with file output and stderr tee
- **Flexible Configuration**: Command-line flags and environment variables
- **Progress Tracking**: Real-time progress reporting with job status
- **Failure Handling**: Option to continue on failures or stop at first failure
- **Verbose Logging**: Detailed execution information for debugging

## Usage

### Basic Usage

```bash
# Run with defaults (auto-detect cores, 10s per test)
make fuzz
# or
nix develop --command ./scripts/fuzz

# Using Nix package directly
nix run .#fuzz
```

### Command Line Options

```bash
fuzz [OPTIONS]

OPTIONS:
    -t, --time SECONDS      Fuzz time per test in seconds (default: 10)
    -j, --jobs N           Number of parallel jobs (default: auto-detect CPU cores)
    -e, --error-file FILE  Write errors to file and tee to stderr
    -c, --continue         Continue on fuzz test failures (don't exit early)
    -v, --verbose          Enable verbose output
    -h, --help             Show help message
```

### Examples

```bash
# Run for 30 seconds per test with 4 parallel jobs
fuzz -t 30 -j 4

# Continue on failures and log errors to file
fuzz -c -e fuzz_errors.log

# Verbose output with extended fuzz time
fuzz --time 60 --verbose

# Comprehensive testing with all options
fuzz -t 120 -j 8 -c -v -e fuzz_results.log
```

### Environment Variables

All options can be configured via environment variables:

```bash
export FUZZ_TIME=30                    # Default fuzz time
export FUZZ_JOBS=8                     # Number of parallel jobs
export FUZZ_ERROR_FILE=fuzz.log        # Error log file
export FUZZ_CONTINUE_ON_FAILURE=true   # Continue on failures
export FUZZ_VERBOSE=true               # Enable verbose output
export FUZZ_CONFIG_DIR=./config        # Configuration directory

# Run with environment configuration
fuzz
```

## How It Works

### Discovery Process

1. **File Discovery**: Searches for `*_test.go` files containing `func Fuzz` patterns
2. **Function Extraction**: Extracts all fuzz function names from discovered files
3. **Target Building**: Creates a list of targets with directory, function, and file information

### Parallel Execution

1. **Job Management**: Maintains a pool of concurrent jobs based on available CPU cores
2. **Load Balancing**: Starts new jobs as others complete to maintain optimal parallelism
3. **Progress Tracking**: Reports real-time progress with completed/failed/running counts

### Error Handling

- **Individual Job Logs**: Each job writes to a separate log file for isolation
- **Error Aggregation**: Failed jobs are tracked and reported in summary
- **File Output**: Errors can be written to a file while simultaneously appearing on stderr
- **Failure Modes**: Option to stop on first failure or continue testing all functions

## Integration with Development Workflow

### Makefile Integration

```bash
make fuzz          # Run fuzz tests
make ci-local      # Includes fuzz testing in CI checks
```

### Pre-commit Integration

The fuzz script can be integrated with pre-commit hooks for continuous testing:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: fuzz-tests
        name: Run fuzz tests
        entry: ./scripts/fuzz
        args: ["-t", "5", "-c"]  # Quick 5s tests, continue on failure
        language: script
        pass_filenames: false
        always_run: true
```

### CI/CD Integration

```bash
# Quick CI fuzz testing
fuzz -t 10 -c -e ci_fuzz_errors.log

# Comprehensive nightly testing
fuzz -t 300 -v -e nightly_fuzz.log
```

## Performance Considerations

### CPU Core Detection

The script automatically detects available CPU cores using:
1. `nproc` command (preferred)
2. `/proc/cpuinfo` parsing (fallback)
3. Default of 4 cores (final fallback)

### Memory Usage

- Each parallel job runs a separate `go test` process
- Memory usage scales with number of parallel jobs
- Consider reducing `-j` value on memory-constrained systems

### Optimal Configuration

```bash
# For development (quick feedback)
fuzz -t 5 -c

# For CI (moderate testing)
fuzz -t 30 -c -e ci_fuzz.log

# For comprehensive testing (long-running)
fuzz -t 600 -v -e comprehensive_fuzz.log
```

## Troubleshooting

### No Fuzz Tests Found

```bash
# Enable verbose output to see discovery process
fuzz -v

# Check for fuzz function naming
grep -r "func Fuzz" . --include="*_test.go"
```

### Performance Issues

```bash
# Reduce parallel jobs
fuzz -j 2

# Check system resources
top
free -h
```

### Build Failures

```bash
# Test individual packages first
go test ./... -v

# Check Go module status
go mod tidy
go mod verify
```

### Error Analysis

```bash
# Use error file for detailed analysis
fuzz -e detailed_errors.log -v

# Check specific failure logs
cat detailed_errors.log | grep "FAILED"
```

## Advanced Usage

### Custom Test Selection

The script discovers all fuzz functions automatically. To run specific tests:

```bash
# Use go test directly for specific functions
go test ./pkg/mypackage -fuzz=FuzzSpecificFunction -fuzztime=30s
```

### Integration with Other Tools

```bash
# Combine with coverage analysis
go test -fuzz=. -fuzztime=60s -coverprofile=fuzz_coverage.out
go tool cover -html=fuzz_coverage.out
```

### Debugging Fuzz Failures

```bash
# Run with verbose output and error logging
fuzz -v -e debug_fuzz.log

# Examine individual job logs (created in temp directory during execution)
# Logs are automatically cleaned up after completion
```

## Configuration Files

The script supports configuration via the `FUZZ_CONFIG_DIR` (default: `./shared`) directory for:

- Custom fuzz test configurations
- Shared environment settings
- Tool-specific configurations

## Best Practices

1. **Development**: Use short fuzz times (`-t 5`) with continue-on-failure (`-c`) for quick feedback
2. **CI/CD**: Use moderate times (`-t 30`) with error logging for automated testing
3. **Nightly Builds**: Use extended times (`-t 600+`) with verbose logging for comprehensive testing
4. **Resource Management**: Adjust parallel jobs (`-j`) based on available system resources
5. **Error Analysis**: Always use error files (`-e`) for production and CI environments

## See Also

- [Go Fuzzing Documentation](https://go.dev/security/fuzz/)
- [DEVELOPMENT.md](./DEVELOPMENT.md) - General development workflow
- [Makefile](./Makefile) - Available make targets including `make fuzz`
