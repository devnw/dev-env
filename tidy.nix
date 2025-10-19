{ pkgs, gomod2nix }:

let
  name = "tidy";
  version = "0.0.1";
  description = "Organize and tidy code dependencies";
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
    go
    nodePackages.npm
    python3
    gomod2nix
  ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/tidy/config
    
    # Copy the main script
    cp scripts/${name} $out/bin/${name}
    chmod +x $out/bin/${name}
    
    # Copy shared configuration files
    if [ -d shared ]; then
      find shared -maxdepth 1 -type f -exec cp {} $out/share/tidy/config/ \;
    fi
    
    # Wrap the script to ensure all dependencies are in PATH and set config path
    wrapProgram $out/bin/${name} \
      --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.go
        pkgs.nodePackages.npm
        pkgs.python3
        gomod2nix
      ]} \
      --set TIDY_CONFIG_DIR "$out/share/tidy/config"
    
    runHook postInstall
  '';
  
  meta = with pkgs.lib; {
    inherit description;
    platforms = platforms.unix;
    maintainers = [ ];
    license = licenses.mit;
  };
}
