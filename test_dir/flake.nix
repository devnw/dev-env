{
  description = "Dev-shell flake with stable base and a pinch of unstable";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

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
              goreleaser
              go-licenses
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
        commonPkgs = with pkgs; [
          nixfmt-rfc-style
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
        ];

        linterPkgs = with pkgs; [
          commitizen
          gibberish-detector
          addlicense
          shfmt
          pre-commit
          shellcheck
          yamllint
          checkmake
        ];

        goPkgs = with pkgs; [
          go
          gopls
          gotools
          go-tools
          delve
          golangci-lint
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
            dart-sass
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

        zigPkgs = with pkgs; [
          zig
          zig-shell-completions
          minizign
          zls
          ztags
          vscode-extensions.ziglang.vscode-zig
          vimPlugins.zig-vim
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
            paths = uiPkgs;
          };
          zigPackages = pkgs.symlinkJoin {
            name = "zig";
            paths = zigPkgs;
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
        };
      }
    )
    // {
      # -------------------- overlay -----------------------------------------
      overlays.default =
        final: prev:
        let
          scripts = import ./scripts.nix { pkgs = final; };
        in
        {
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
    };

  nixConfig = {
    extra-substituters = [ "https://oss-devnw.cachix.org" ];
    extra-trusted-public-keys = [
      "oss-devnw.cachix.org-1:ihw2M3SGlG7jiEa1TolVbRfKyR6waZiRpbwdkWOF2zw="
    ];
  };
}
