{ pkgs, ... }:
{
  # pkgs.gh vient de l'overlay unstable (overlays/unstable-packages.nix)
  programs.gh = {
    enable = true;
    package = pkgs.gh;
  };
}
