{
  description = "Dev-shell flake with stable base and a pinch of unstable";

  # All inputs support 'follows' from parent flakes for better dependency management
  # Example usage in parent flake:
  #   inputs.dev-env = {
  #     url = "github:devnw/dev-env";
  #     inputs.nixpkgs.follows = "nixpkgs";
  #     inputs.unstable.follows = "nixpkgs-unstable";
  #     inputs.flake-utils.follows = "flake-utils";
  #   };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    # Optional: canary tools from devnw
    # Note: If this repository is not accessible, you can override this input
    # or set devnwPkgs to [] in your parent flake
    canary = {
      url = "github:devnw/canary";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Go module tooling
    gomod2nix = {
      url = "github:tweag/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      unstable,
      flake-utils,
      gomod2nix,
      canary,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # --- channel imports --------------------------------------------------
        pkgs-stable = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        pkgs-unstable = import unstable {
          inherit system;
          config.allowUnfree = true;
        };

        # --- merge a handful of unstable packages into the stable set ---------
        pkgs = pkgs-stable.extend (
          final: prev: {
            inherit (pkgs-unstable)
              go
              gopls
              go-tools
              delve
              golangci-lint
              golangci-lint-langserver
              goreleaser
              go-licenses
              zig
              ;

            python = pkgs-unstable.python3.withPackages (
              ps: with ps; [
                hvac
                openapi-spec-validator
                detect-secrets
                requests
                python-dotenv
                libxml2
                distutils
              ]
            );
          }
        );

        # Import canary packages if available (can be overridden via follows in parent flakes)
        # Canary is expected to export a list of packages, but we default to empty if not available
        devnwPkgs =
          if canary ? packages.${system} then
            (builtins.attrValues canary.packages.${system})
          else if canary ? defaultPackage.${system} then
            [ canary.defaultPackage.${system} ]
          else
            [ ];

        # --- import shell scripts ---------------------------------------------
        scripts = import ./scripts.nix {
          inherit pkgs;
          gomod2nix = gomod2nix.packages.${system}.default;
        };

        # Helper
        isDarwin = builtins.elem system [
          "aarch64-darwin"
          "x86_64-darwin"
        ];

        # --- convenience lists (must stay lists!) -----------------------------
        commonPkgs =
          with pkgs;
          [
            nixfmt-rfc-style
            nil # nix language server
            statix

            cachix
            gnumake
            openssh
            bash
            curl
            which
            gcc
            ruby
            gawk
            git
            sqlite-interactive
            rsync
            python
            _1password-cli

            nodePackages.prettier

            jq
            vault

            act
            gh
            codex

            # Shell scripts
            scripts.fmt
            scripts.cex
            scripts.lint
            scripts.tidy
            scripts.upgrade
            scripts.fuzz
            scripts.fuzz-go
            scripts.license
            scripts.tag
            scripts.godoc
          ]
          ++ devnwPkgs;

        linterPkgs = with pkgs; [
          commitizen
          gibberish-detector
          addlicense
          shfmt
          pre-commit
          shellcheck
          yamllint
          checkmake
          eslint
          black
          rslint
        ];

        goPkgs = with pkgs; [
          go
          gopls
          gotools
          go-tools
          delve
          golangci-lint
          golangci-lint-langserver
          goreleaser
          go-licenses
          gomod2nix.packages.${system}.default
        ];

        ansiblePkgs = with pkgs; [
          (python3.withPackages (ps: with ps; [ hvac ]))
          openssh
          ansible
          ansible-lint
          molecule
          vault
        ];

        nodePkgs = with pkgs; [
          nodejs
          npm-check-updates
          nodePackages.npm
        ];

        hugoPkgs =
          with pkgs;
          [
            prettier-plugin-go-template
            dart-sass
            hugo
          ]
          ++ uiPkgs;

        seoPkgs =
          with pkgs;
          [
            google-lighthouse
          ]
          ++ hugoPkgs;

        uiPkgs =
          with pkgs;
          [
            playwright
            (python3.withPackages (ps: with ps; [ playwright ]))
            nodePackages.webpack
            nodePackages.webpack-cli
            nodePackages.sass
            nodePackages.typescript
            nodePackages.typescript-language-server
            nodePackages.prettier
          ]
          ++ nodePkgs;

        gdk = pkgs.google-cloud-sdk.withExtraComponents (
          with pkgs.google-cloud-sdk.components; [ gke-gcloud-auth-plugin ]
        );

        tfPkgs = with pkgs; [
          curl
          which
          git

          # lint tools
          gibberish-detector
          addlicense
          shfmt
          pre-commit
          shellcheck

          azure-cli
          awscli
          gdk

          certstrap
          terraform

          tflint
          tflint-plugins.tflint-ruleset-aws
          tflint-plugins.tflint-ruleset-google

          kubectl

          terraform
          terraform-lsp
          terraform-docs
          tfsec
        ];

        ciPkgs =
          with pkgs;
          [
            docker
            docker-compose
            act
            gh
            terraform
            kubectl
            pkgs-unstable.doctl
            s3cmd
            gdk
            awscli2
            azure-cli
          ]
          ++ (if isDarwin then [ docker-credential-helpers ] else [ ]);

        nixPkgs = with pkgs; [
          nixfmt-rfc-style
          inetutils
          coreutils
          cachix
          nix
          nixos-rebuild
          nixos-install
          vulnix
          python
        ];

        zigPkgs =
          let
            zigPkg = pkgs-unstable.zig_0_15;
            zlsPkg = pkgs-unstable.zls_0_15;
          in
          [
            zigPkg
            pkgs-unstable.zig-shell-completions
            pkgs-unstable.minizign
            zlsPkg
            pkgs-unstable.ztags
            pkgs-unstable.vscode-extensions.ziglang.vscode-zig
            pkgs-unstable.vimPlugins.zig-vim
          ];
      in
      {
        # -------------------- exported packages (must be derivations) ----------
        packages = {
          default = pkgs.writeText "placeholder" "";
          commonPackages = pkgs.symlinkJoin {
            name = "common";
            paths = commonPkgs ++ linterPkgs;
          };
          goPackages = pkgs.symlinkJoin {
            name = "go";
            paths = goPkgs;
          };
          terraformPackages = pkgs.symlinkJoin {
            name = "terraform";
            paths = tfPkgs;
          };
          ansiblePackages = pkgs.symlinkJoin {
            name = "ansible";
            paths = ansiblePkgs;
          };
          nixPackages = pkgs.symlinkJoin {
            name = "nix";
            paths = nixPkgs;
          };
          uiPackages = pkgs.symlinkJoin {
            name = "ui";
            paths = uiPkgs ++ linterPkgs;
          };
          zigPackages = pkgs.symlinkJoin {
            name = "zig";
            paths = zigPkgs;
          };
          nodePackages = pkgs.symlinkJoin {
            name = "node";
            paths = nodePkgs;
          };
          hugoPackages = pkgs.symlinkJoin {
            name = "hugo";
            paths = hugoPkgs;
          };
          seoPackages = pkgs.symlinkJoin {
            name = "seo";
            paths = seoPkgs;
          };

          # Individual shell scripts
          inherit (scripts)
            cex
            fmt
            lint
            tidy
            upgrade
            fuzz
            fuzz-go
            license
            tag
            ;
        };

        # -------------------- development shells ------------------------------
        devShells = {
          default = pkgs.mkShell {
            buildInputs = commonPkgs ++ linterPkgs ++ goPkgs ++ ansiblePkgs ++ nixPkgs;
          };
          zig = pkgs.mkShell { buildInputs = commonPkgs ++ linterPkgs ++ zigPkgs; };
          go = pkgs.mkShell { buildInputs = commonPkgs ++ linterPkgs ++ goPkgs; };
          go-ui = pkgs.mkShell { buildInputs = commonPkgs ++ linterPkgs ++ goPkgs ++ uiPkgs; };
          ansible = pkgs.mkShell { buildInputs = commonPkgs ++ ansiblePkgs; };
          terraform = pkgs.mkShell {
            buildInputs = commonPkgs ++ linterPkgs ++ tfPkgs;
          };
          nix = pkgs.mkShell { buildInputs = commonPkgs ++ nixPkgs; };
          ci = pkgs.mkShell { buildInputs = commonPkgs ++ linterPkgs ++ goPkgs ++ ansiblePkgs ++ ciPkgs; };
          node = pkgs.mkShell { buildInputs = commonPkgs ++ linterPkgs ++ nodePkgs; };
          ui = pkgs.mkShell { buildInputs = commonPkgs ++ linterPkgs ++ uiPkgs; };
          hugo = pkgs.mkShell { buildInputs = commonPkgs ++ linterPkgs ++ uiPkgs ++ hugoPkgs; };
          seo = pkgs.mkShell { buildInputs = commonPkgs ++ linterPkgs ++ uiPkgs ++ hugoPkgs ++ seoPkgs; };
        };
      }
    )
    // {
      # -------------------- overlay -----------------------------------------
      # Note: overlay doesn't include gomod2nix-dependent scripts
      # to avoid circular dependencies when used in other flakes
      overlays.default = final: prev: {
        dev-env-scripts = prev.callPackage ./scripts.nix {
          pkgs = final;
          # gomod2nix is omitted in overlay to avoid dependency issues
          # when this flake is used via follows in parent flakes
          gomod2nix = null;
        };
      };
    };

  nixConfig = {
    extra-substituters = [
      "https://oss-devnw.cachix.org"
      "https://oss-spyder.cachix.org"
      "https://oss-codepros.cachix.org"
    ];
    extra-trusted-public-keys = [
      "oss-devnw.cachix.org-1:iJblmQB0mX8MTEqkKJv3piJK3mimEbHpgU1+FSeRuGY="
      "oss-spyder.cachix.org-1:CMypXJpvr7z6IGQdIGDHgZBaZX7JSX9AuPErD/in01g="
      "oss-codepros.cachix.org-1:dP82KzkIxKQp+kS1RgxasR9JYlFdy4W9y7heHeD5h34="
    ];
  };
}
