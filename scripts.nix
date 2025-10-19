{
  pkgs,
  gomod2nix ? null,
}:

let
  # Import sophisticated packages with dependencies
  pre-commit-global = import ./pre-commit.nix { inherit pkgs; };
  fmt = import ./fmt.nix { inherit pkgs; };
  lint = import ./lint.nix { inherit pkgs; };
  upgrade = import ./upgrade.nix { inherit pkgs; };
  cex = import ./cex.nix { inherit pkgs; };
  fuzz = import ./fuzz.nix { inherit pkgs; };
  fuzz-go = import ./fuzz-go.nix { inherit pkgs; };
  license = import ./license.nix { inherit pkgs; };
  tag = import ./tag.nix { inherit pkgs; };
  godoc = import ./godoc.nix { inherit pkgs; };

  # Only include tidy if gomod2nix is provided
  optionalTidy =
    if gomod2nix != null then
      {
        tidy = import ./tidy.nix {
          inherit pkgs;
          gomod2nix = gomod2nix;
        };
      }
    else
      { };
in
{
  # Use the sophisticated packages with bundled dependencies
  inherit
    fmt
    lint
    upgrade
    cex
    fuzz
    fuzz-go
    license
    tag
    godoc
    pre-commit-global
    ;
}
// optionalTidy
