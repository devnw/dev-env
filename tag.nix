{ pkgs }:

let
  name = "tag";
  version = "0.0.1";
  description = "Manage version tags and releases";
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
  ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/tag/config
    
    # Copy the main script
    cp scripts/tag.py $out/bin/${name}
    chmod +x $out/bin/${name}
    
    # Copy shared configuration files
    if [ -d shared ]; then
      find shared -maxdepth 1 -type f -exec cp {} $out/share/tag/config/ \;
    fi
    
    # Wrap the script to ensure all dependencies are in PATH and set config path
    wrapProgram $out/bin/${name} \
      --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.python3
        pkgs.git
      ]} \
      --set TAG_CONFIG_DIR "$out/share/tag/config"
    
    runHook postInstall
  '';
  
  meta = with pkgs.lib; {
    inherit description;
    platforms = platforms.unix;
    maintainers = [ ];
    license = licenses.mit;
  };
}
