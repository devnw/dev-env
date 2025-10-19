{ pkgs }:

let
  name = "pre-commit-global";
  version = "0.0.1";
  description = "Pre-commit wrapper that always uses the shared config from this flake";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = name;
  inherit version;
  # Include the repo root so we can copy shared/.pre-commit-config.yaml and .sqlfluff
  src = ./.;
  dontBuild = true;
  doCheck = false;
  dontUsePytestCheckHook = true;
  checkPhase = ''
    echo "Skipping tests for ${name}"
  '';

  nativeBuildInputs = with pkgs; [
    makeWrapper
  ];

  # Avoid bringing in pytest hooks via Python packages here; wrapProgram will
  # reference them directly so they are in the runtime closure.
  buildInputs = [ ];

  installPhase = ''
    set -euo pipefail

    mkdir -p $out/bin
    mkdir -p $out/share/pre-commit

    if [ -f shared/.pre-commit-config.yaml ]; then
      cp shared/.pre-commit-config.yaml $out/share/pre-commit/.pre-commit-config.yaml
    else
      echo "ERROR: Missing shared/.pre-commit-config.yaml in source" >&2
      exit 1
    fi

    if [ -f shared/.sqlfluff ]; then
      cp shared/.sqlfluff $out/share/pre-commit/.sqlfluff
    fi

    cat > $out/bin/pre-commit-global <<'EOF'
    #!/usr/bin/env bash
    set -euo pipefail

    DEFAULT_CONFIG="@OUT@/share/pre-commit/.pre-commit-config.yaml"
    DEFAULT_SQLFLUFF="@OUT@/share/pre-commit/.sqlfluff"

    # Allow override via env
    CONFIG="''${PRECOMMIT_CONFIG:-$DEFAULT_CONFIG}"

    # Default sqlfluff config unless user overrides
    if [ -f "$DEFAULT_SQLFLUFF" ] && [ -z "''${SQLFLUFF_CONFIG:-}" ]; then
      export SQLFLUFF_CONFIG="$DEFAULT_SQLFLUFF"
    fi

    has_config=0
    for a in "$@"; do
      if [ "$a" = "-c" ] || [ "$a" = "--config" ]; then
        has_config=1
        break
      fi
    done

    if [ $has_config -eq 0 ]; then
      exec pre-commit --config "$CONFIG" "$@"
    else
      exec pre-commit "$@"
    fi
    EOF

    substituteInPlace $out/bin/pre-commit-global --subst-var-by OUT "$out"
    chmod +x $out/bin/pre-commit-global

    # Provide a 'pre-commit' binary to shadow upstream when early in PATH
    ln -s $out/bin/pre-commit-global $out/bin/pre-commit

    wrapProgram $out/bin/pre-commit-global \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.pre-commit
          pkgs.git
          pkgs.sqlfluff
        ]
      }

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    inherit description;
    platforms = platforms.unix;
    license = licenses.mit;
    maintainers = [ ];
  };
}
