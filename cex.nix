{ pkgs }:

let
  name = "cex";
  version = "0.0.1";
  description = "Curl and Execute scripts from shared repository";
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
    curl
    bash
    coreutils
  ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/cex/config
    
    # Copy the main script
    cp scripts/${name} $out/bin/${name}
    chmod +x $out/bin/${name}
    
    # Copy shared configuration files
    if [ -d shared ]; then
      find shared -maxdepth 1 -type f -exec cp {} $out/share/cex/config/ \;
    fi
    
    # Wrap the script to ensure all dependencies are in PATH and set config path
    wrapProgram $out/bin/${name} \
      --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.curl
        pkgs.bash
        pkgs.coreutils
      ]} \
      --set CEX_CONFIG_DIR "$out/share/cex/config"
    
    runHook postInstall
  '';
  
  meta = with pkgs.lib; {
    inherit description;
    platforms = platforms.unix;
    maintainers = [ ];
    license = licenses.mit;
  };
}
