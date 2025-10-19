{ pkgs }:

let
  name = "fuzz";
  version = "0.0.1";
  description = "Run fuzzing tests for Go projects";
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
    python3
  ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/fuzz/config
    
    # Copy the Python script
    cp scripts/${name}.py $out/bin/${name}
    chmod +x $out/bin/${name}
    
    # Copy shared configuration files
    if [ -d shared ]; then
      find shared -maxdepth 1 -type f -exec cp {} $out/share/fuzz/config/ \;
    fi
    
    # Wrap the script to ensure all dependencies are in PATH and set config path
    wrapProgram $out/bin/${name} \
      --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.go
        pkgs.python3
      ]} \
      --set FUZZ_CONFIG_DIR "$out/share/fuzz/config"
    
    runHook postInstall
  '';
  
  meta = with pkgs.lib; {
    inherit description;
    platforms = platforms.unix;
    maintainers = [ ];
    license = licenses.mit;
  };
}
