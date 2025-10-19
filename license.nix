{ pkgs }:

let
  name = "license";
  version = "0.0.1";
  description = "Manage and validate license headers in source files";
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
    python3
    git
    addlicense
  ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/license/config

    # Copy the main script
    cp scripts/license.py $out/bin/${name}
    chmod +x $out/bin/${name}

    # Copy shared configuration files
    if [ -d shared ]; then
      find shared -maxdepth 1 -type f -exec cp {} $out/share/license/config/ \;
    fi

    # Wrap the script to ensure all dependencies are in PATH and set config path
    wrapProgram $out/bin/${name} \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.python3
          pkgs.git
          pkgs.addlicense
        ]
      } \
      --set LICENSE_CONFIG_DIR "$out/share/license/config"

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    inherit description;
    platforms = platforms.unix;
    maintainers = [ ];
    license = licenses.mit;
  };
}
