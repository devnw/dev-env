{ pkgs }:

let
  name = "fmt";
  version = "0.0.1";
  description = "Format code using various tools";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = name;
  inherit version;
  src = ./.;
  dontBuild = true;

  nativeBuildInputs = with pkgs; [
    makeWrapper
  ];

  buildInputs = with pkgs; [
    nixfmt-rfc-style
    nodePackages.prettier
    nodePackages.eslint
    shfmt
    go
    gotools # contains goimports
    golangci-lint
    python3Packages.black
    python3Packages.isort
    python3Packages.autopep8
    rustfmt
    zig
    jq
    yq-go
    yamllint
    sql-formatter
    # PostgreSQL SQL syntax beautifier that can work as a console
    # program or as a CGI
    pgformatter
    sqlfluff
    taplo # TOML formatter
  ];

  installPhase = ''
        mkdir -p $out/bin
        mkdir -p $out/share/fmt/config

        # Copy the main script
        cp scripts/${name} $out/bin/${name}
        chmod +x $out/bin/${name}

        # Copy shared configuration files (including hidden files)
        if [ -d shared ]; then
          find shared -maxdepth 1 -type f -exec cp {} $out/share/fmt/config/ \;
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
              pkgs.nixfmt-rfc-style
              pkgs.nodePackages.prettier
              pkgs.nodePackages.eslint
              pkgs.shfmt
              pkgs.go
              pkgs.gotools
              pkgs.golangci-lint
              pkgs.python3Packages.black
              pkgs.python3Packages.isort
              pkgs.python3Packages.autopep8
              pkgs.rustfmt
              pkgs.zig
              pkgs.jq
              pkgs.yq-go
              pkgs.yamllint
              pkgs.sql-formatter
              pkgs.pgformatter
              pkgs.sqlfluff
              pkgs.taplo
            ]
          }:$out/bin \
          --set FMT_CONFIG_DIR "$out/share/fmt/config"

        runHook postInstall
  '';

  meta = with pkgs.lib; {
    inherit description;
    platforms = platforms.unix;
    maintainers = [ ];
    license = licenses.mit;
  };
}
