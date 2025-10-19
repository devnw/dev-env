{ pkgs }:

let
  name = "upgrade";
  version = "0.0.1";
  description = "Upgrade project dependencies and tools";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = name;
  inherit version;
  src = ./.;
  dontBuild = true;
  doCheck = false;
  dontFixup = false;
  
  phases = [ "unpackPhase" "installPhase" "fixupPhase" ];
  
  nativeBuildInputs = with pkgs; [
    makeWrapper
  ];
  
  buildInputs = with pkgs; [
    git
    pre-commit
    nix
    nodePackages.npm
    python3
    go
  ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/upgrade/config
    
    # Copy the main script
    cp scripts/${name} $out/bin/${name}
    chmod +x $out/bin/${name}
    
    # Copy shared configuration files
    if [ -d shared ]; then
      find shared -maxdepth 1 -type f -exec cp {} $out/share/upgrade/config/ \;
    fi
    
    # Wrap the script to ensure all dependencies are in PATH and set config path
    wrapProgram $out/bin/${name} \
      --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.git
        pkgs.pre-commit
        pkgs.nix
        pkgs.nodePackages.npm
        pkgs.python3
        pkgs.go
      ]} \
      --set UPGRADE_CONFIG_DIR "$out/share/upgrade/config"
    
    runHook postInstall
  '';
  
  meta = with pkgs.lib; {
    inherit description;
    platforms = platforms.unix;
    maintainers = [ ];
    license = licenses.mit;
  };
}
