{
  pkgs,
  ...
}:
{
  imports = [
    ./fish.nix
    ./bat.nix
    ./eza.nix
    ./starship.nix
    ./helix.nix
    ./fresh.nix
    ./theme-auto.nix
  ];

  # LSP markdown, partagé par helix et fresh-editor
  home.packages = [ pkgs.marksman ];

  programs.nix-index-database.comma.enable = true;
}
