# Cachix Binary Cache Setup

This repository uses [Cachix](https://cachix.org/) to provide pre-built binaries for faster builds and CI/CD.

## For Users

The binary cache is automatically configured in the flake. You don't need to do anything special - just use the flake normally and you'll get cached builds when available:

```bash
# These will use pre-built packages from cache
nix develop
nix build .#cex
nix shell github:devnw/flakes#fmt
```

## For Contributors and Maintainers

### Prerequisites

1. Install Cachix:

   ```bash
   nix-env -iA cachix -f https://cachix.org/api/v1/install
   ```

2. Get an authentication token:

   - Visit [https://app.cachix.org/cache/oss-devnw](https://app.cachix.org/cache/oss-devnw)
   - Generate a personal auth token

### Authentication Setup

1. Set your auth token:

   ```bash
   export CACHIX_AUTH_TOKEN=your_token_here
   ```

2. Configure Cachix:

   ```bash
   make setup-cachix
   ```

### Pushing to Cache

#### Automated (Recommended)

The GitHub Actions workflows automatically build and push packages to Cachix on:

- Every push to main branch
- Daily scheduled builds
- Manual workflow dispatch

#### Manual Push

```bash
# Push all package sets
make push-cachix

# Push individual scripts only
make push-scripts-cachix

# Push specific packages
nix build .#cex | cachix push oss-devnw
nix build .#commonPackages | cachix push oss-devnw
```

### GitHub Actions Configuration

For CI/CD to push to Cachix, ensure the `CACHIX_AUTH_TOKEN` secret is set in repository settings:

1. Go to repository Settings > Secrets and variables > Actions
2. Add new repository secret:
   - Name: `CACHIX_AUTH_TOKEN`
   - Value: Your Cachix auth token

## Cache Benefits

- **Faster CI/CD**: Pre-built packages reduce build times from minutes to seconds
- **Developer Experience**: Instant `nix develop` shell activation
- **Bandwidth Savings**: Binary downloads instead of source compilation
- **Consistency**: Same builds across all environments

## Cache Contents

The cache includes:

### Individual Scripts

- `cex` - Curl and Execute utility
- `fmt` - Code formatting script
- `lint` - Code linting script
- `tidy` - Code organization script
- `upgrade` - Dependency upgrade script
- `fuzz` - Fuzzing test script
- `fuzz-go` - Go-specific fuzzing script
- `license` - License management script
- `tag` - Version tagging script

### Package Sets

- `commonPackages` - Common development tools
- `goPackages` - Go development environment
- `terraformPackages` - Terraform tools
- `ansiblePackages` - Ansible environment
- `nixPackages` - Nix development tools
- `uiPackages` - UI development environment
- `zigPackages` - Zig development environment

### Development Shells

All development shell environments are pre-built and cached for instant activation.

## Troubleshooting

### Authentication Issues

```bash
# Check if authenticated
cachix authtoken --help

# Re-authenticate
make setup-cachix
```

### Push Failures

```bash
# Verify token has push permissions
echo $CACHIX_AUTH_TOKEN | cachix authtoken --stdin

# Check cache exists and you have access
cachix use oss-devnw 
```

### Cache Miss

If you're not getting cached builds:

```bash
# Check cache configuration
nix show-config | grep substituters

# Verify cache is accessible
nix ping-store https://oss-devnw.cachix.org
```
