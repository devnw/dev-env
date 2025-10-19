{ pkgs }:

let
  name = "fuzz-go";
  version = "0.0.1";
  description = "Python-based Go fuzzing test runner";
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
    go
  ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/fuzz-go/config
    
    # Copy the main script
    cp scripts/fuzz_go.py $out/bin/${name}
    chmod +x $out/bin/${name}
    
    # Copy shared configuration files
    if [ -d shared ]; then
      find shared -maxdepth 1 -type f -exec cp {} $out/share/fuzz-go/config/ \;
    fi
    
    # Wrap the script to ensure all dependencies are in PATH and set config path
    wrapProgram $out/bin/${name} \
      --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.python3
        pkgs.go
      ]} \
      --set FUZZ_GO_CONFIG_DIR "$out/share/fuzz-go/config"
    
    runHook postInstall
  '';
  
  meta = with pkgs.lib; {
    inherit description;
    platforms = platforms.unix;
    maintainers = [ ];
    license = licenses.mit;
  };
}
