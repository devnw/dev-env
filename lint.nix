{ pkgs }:

let
  inherit (pkgs) callPackage;
  licensePkg = callPackage ./license.nix { };
in

let
  name = "lint";
  version = "0.0.1";
  description = "Lint code using various tools";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = name;
  inherit version;
  src = ./.;
  dontBuild = true;
  doCheck = false;

  nativeBuildInputs = with pkgs; [
    makeWrapper
  ];

  buildInputs = with pkgs; [
    # Include license checker
    licensePkg
    checkmake
    golangci-lint
    golangci-lint-langserver
    nodePackages.eslint
    nodePackages.prettier
    shellcheck
    python3Packages.flake8
    python3Packages.pylint
    python3Packages.black
    python3Packages.isort
    python3Packages.yamllint
    nixfmt-rfc-style
    statix
    sqlfluff
    squawk
    zig-zlint
    jq
    yq-go
    redocly
  ];

  installPhase = ''
        mkdir -p $out/bin
        mkdir -p $out/share/lint/config

        # Copy the main script
        cp scripts/${name} $out/bin/${name}
        chmod +x $out/bin/${name}

        # Copy shared configuration files
        if [ -d shared ]; then
          find shared -maxdepth 1 -type f -exec cp {} $out/share/lint/config/ \;
        fi

        # Create nixfmt-tree wrapper for directory formatting
        cat > $out/bin/nixfmt-tree <<'EOF'
    #!/usr/bin/env bash
    set -euo pipefail
    # Wrapper for nixfmt that recursively formats Nix files in directories
    # This avoids the deprecated behavior of passing directories to nixfmt directly

    ARGS=()
    DIRS=()

    for arg in "$@"; do
      if [[ -d "$arg" ]]; then
        DIRS+=("$arg")
      else
        ARGS+=("$arg")
      fi
    done

    if [[ ''${#DIRS[@]} -gt 0 ]]; then
      for dir in "''${DIRS[@]}"; do
        find "$dir" -name "*.nix" -type f -exec nixfmt "''${ARGS[@]}" {} +
      done
    else
      nixfmt "''${ARGS[@]}"
    fi
    EOF
        chmod +x $out/bin/nixfmt-tree

        # Wrap nixfmt-tree to ensure nixfmt is in PATH
        wrapProgram $out/bin/nixfmt-tree \
          --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nixfmt-rfc-style ]}

        # Wrap the script to ensure all dependencies are in PATH and set config path
        wrapProgram $out/bin/${name} \
          --prefix PATH : ${
            pkgs.lib.makeBinPath [
              pkgs.checkmake
              pkgs.golangci-lint
              pkgs.golangci-lint-langserver
              pkgs.nodePackages.eslint
              pkgs.nodePackages.prettier
              pkgs.shellcheck
              pkgs.python3Packages.flake8
              pkgs.python3Packages.pylint
              pkgs.python3Packages.black
              pkgs.python3Packages.isort
              pkgs.python3Packages.yamllint
              pkgs.nixfmt-rfc-style
              pkgs.statix
              pkgs.sqlfluff
              pkgs.squawk
              pkgs.postgresql
              pkgs.zig-zlint
              pkgs.jq
              pkgs.yq-go
              pkgs.redocly
              licensePkg
            ]
          }:$out/bin \
          --set LINT_CONFIG_DIR "$out/share/lint/config"

        runHook postInstall
  '';

  meta = with pkgs.lib; {
    inherit description;
    platforms = platforms.unix;
    maintainers = [ ];
    license = licenses.mit;
  };
}
