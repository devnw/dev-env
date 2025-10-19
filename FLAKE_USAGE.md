# Using dev-env Flake in Other Projects

This flake is designed to be used as a dependency in other flakes with full support for the `follows` mechanism, allowing you to control dependency versions from your parent flake.

## Basic Usage

### As a Direct Dependency

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    dev-env.url = "github:devnw/dev-env";
  };

  outputs = { self, nixpkgs, dev-env }: {
    # Use dev-env packages directly
    devShells.default = dev-env.devShells.${system}.default;

    # Or use individual packages
    packages.fmt = dev-env.packages.${system}.fmt;
  };
}
```

## Using `follows` for Dependency Management

The `follows` mechanism allows you to ensure all dependencies use the same version of nixpkgs and other inputs, avoiding duplicate downloads and potential version conflicts.

### Recommended Pattern

```nix
{
  inputs = {
    # Your primary nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Shared utilities
    flake-utils.url = "github:numtide/flake-utils";

    # dev-env with follows for all its inputs
    dev-env = {
      url = "github:devnw/dev-env";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        unstable.follows = "nixpkgs-unstable";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, dev-env, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system: {
      devShells.default = dev-env.devShells.${system}.go;
    });
}
```

## Available Inputs for `follows`

All dev-env inputs support `follows`:

- **`nixpkgs`** - Main stable nixpkgs (currently 25.05)
- **`unstable`** - Unstable nixpkgs for newer packages
- **`flake-utils`** - Flake utilities for multi-system builds
- **`gomod2nix`** - Go module tooling (auto-follows nixpkgs)
- **`canary`** - Optional devnw canary tools (auto-follows nixpkgs)

### Example: Override All Inputs

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    dev-env = {
      url = "github:devnw/dev-env";
      inputs = {
        # Use your nixpkgs for both stable and unstable
        nixpkgs.follows = "nixpkgs";
        unstable.follows = "nixpkgs";

        # Share flake-utils if you already use it
        flake-utils.follows = "flake-utils";

        # gomod2nix and canary will automatically follow nixpkgs
        # since they're configured to follow dev-env's nixpkgs
      };
    };
  };
}
```

## Using the Overlay

The dev-env flake provides an overlay that adds all development scripts to nixpkgs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    dev-env.url = "github:devnw/dev-env";
  };

  outputs = { self, nixpkgs, dev-env }: {
    devShells.default = let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ dev-env.overlays.default ];
      };
    in pkgs.mkShell {
      buildInputs = [
        pkgs.dev-env-scripts.fmt
        pkgs.dev-env-scripts.lint
        # Other scripts available:
        # cex, upgrade, fuzz, fuzz-go, license, tag, godoc, pre-commit-global
      ];
    };
  };
}
```

**Note:** The overlay does not include the `tidy` script to avoid circular dependencies with gomod2nix. Use the package directly if you need tidy functionality.

## Available Development Shells

```nix
dev-env.devShells.${system}.default  # Full development environment
dev-env.devShells.${system}.go       # Go development
dev-env.devShells.${system}.node     # Node.js development
dev-env.devShells.${system}.terraform # Infrastructure as code
dev-env.devShells.${system}.ansible  # Configuration management
dev-env.devShells.${system}.nix      # Nix development
dev-env.devShells.${system}.zig      # Zig development
dev-env.devShells.${system}.ui       # UI development (Node + testing)
dev-env.devShells.${system}.hugo     # Hugo static site development
dev-env.devShells.${system}.ci       # CI/CD tooling
```

## Available Packages

Individual scripts and package collections:

```nix
# Individual scripts
dev-env.packages.${system}.fmt       # Multi-language formatter
dev-env.packages.${system}.lint      # Multi-language linter
dev-env.packages.${system}.cex       # Curl and execute utility
dev-env.packages.${system}.tidy      # Code cleanup (requires gomod2nix)
dev-env.packages.${system}.upgrade   # Dependency upgrader
dev-env.packages.${system}.fuzz      # Parallel fuzzing tool
dev-env.packages.${system}.fuzz-go   # Go fuzzing
dev-env.packages.${system}.license   # License header management
dev-env.packages.${system}.tag       # Version tagging utility

# Package collections
dev-env.packages.${system}.commonPackages    # Core development tools
dev-env.packages.${system}.goPackages        # Go toolchain
dev-env.packages.${system}.nodePackages      # Node.js tools
dev-env.packages.${system}.terraformPackages # Terraform tooling
dev-env.packages.${system}.ansiblePackages   # Ansible tooling
dev-env.packages.${system}.nixPackages       # Nix development tools
dev-env.packages.${system}.zigPackages       # Zig toolchain
dev-env.packages.${system}.uiPackages        # UI testing tools
```

## Benefits of Using `follows`

1. **Reduced Disk Usage**: Only one copy of nixpkgs is downloaded
2. **Faster Evaluation**: Nix doesn't need to evaluate multiple nixpkgs versions
3. **Version Consistency**: All dependencies use the same package versions
4. **Easier Updates**: Update nixpkgs once, all dependencies follow
5. **Predictable Builds**: Avoid conflicts from different nixpkgs versions

## Troubleshooting

### Canary Input Not Available

The canary input is optional and gracefully degrades if not available. If the canary flake doesn't export the expected packages, the flake will use an empty list and continue working normally.

If you want to completely override it:

```nix
dev-env = {
  url = "github:devnw/dev-env";
  inputs = {
    nixpkgs.follows = "nixpkgs";
    # You can override canary to point to your own flake
    canary.url = "github:yourorg/your-canary-fork";
  };
};
```

### Darwin SDK Deprecation Warning

On macOS systems, you may see a warning:
```
evaluation warning: darwin.apple_sdk_11_0.callPackage: deprecated and will be removed in Nixpkgs 25.11
```

This is a known nixpkgs internal warning from transitive dependencies (like docker-credential-helpers). It's not an error and doesn't affect functionality. The warning will be resolved when upgrading to nixpkgs 25.11 or later. You can safely ignore it for now.

### gomod2nix Conflicts

If you have your own gomod2nix setup:

```nix
dev-env = {
  url = "github:devnw/dev-env";
  inputs = {
    gomod2nix.follows = "gomod2nix";  # Use your gomod2nix
  };
};
```

## Example: Full Integration

```nix
{
  description = "My project using dev-env";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    dev-env = {
      url = "github:devnw/dev-env";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        unstable.follows = "nixpkgs-unstable";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, dev-env, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        devShells = {
          # Use dev-env's Go shell
          default = dev-env.devShells.${system}.go;

          # Or create a custom shell with dev-env packages
          custom = pkgs.mkShell {
            buildInputs = with dev-env.packages.${system}; [
              fmt
              lint
              commonPackages
              goPackages
            ];
          };
        };

        # Use dev-env scripts in your CI
        packages.ci-check = pkgs.writeShellScriptBin "ci-check" ''
          ${dev-env.packages.${system}.fmt}/bin/fmt --check
          ${dev-env.packages.${system}.lint}/bin/lint
        '';
      }
    );
}
```

## See Also

- [Nix Flakes - follows](https://nixos.wiki/wiki/Flakes#Using_flakes_with_stable_Nix)
- [CLAUDE.md](./CLAUDE.md) - Development commands and architecture
- [DEVELOPMENT.md](./DEVELOPMENT.md) - Development workflow
