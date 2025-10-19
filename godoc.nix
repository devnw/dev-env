{ pkgs }:

let
  name = "godocdown";
  version = "0.0.1";
  description = "Go Doc Writer";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = name;
  inherit version;
  
  src = pkgs.fetchgit {
    url = "https://github.com/robertkrimen/godocdown";
    rev = "refs/heads/master";
    sha256 = "sha256-5gGun9CTvI3VNsMudJ6zjrViy6Zk00NuJ4pZJbzY/Uk=";
  };

  nativeBuildInputs = with pkgs; [
    go
  ];

  buildPhase = ''
    runHook preBuild
    
    # Set up GOPATH and cache for legacy Go project
    export GOPATH=$TMPDIR/go
    export GOCACHE=$TMPDIR/go-cache
    export GO111MODULE=off
    mkdir -p $GOPATH/src/github.com/robertkrimen
    mkdir -p $GOCACHE
    cp -r $src $GOPATH/src/github.com/robertkrimen/godocdown
    chmod -R +w $GOPATH/src/github.com/robertkrimen/godocdown
    
    cd $GOPATH/src/github.com/robertkrimen/godocdown/godocdown
    go build -o $TMPDIR/godocdown-bin .
    
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp $TMPDIR/godocdown-bin $out/bin/godocdown
    runHook postInstall
  '';
  
  meta = with pkgs.lib; {
    inherit description;
    homepage = "https://github.com/robertkrimen/godocdown";
    platforms = platforms.unix;
    maintainers = [ ];
    license = licenses.mit;
  };
}
