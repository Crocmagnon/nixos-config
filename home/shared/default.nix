{
  imports = [
    ./fish.nix
    ./eza.nix
    ./starship.nix
    ./helix.nix
  ];

  programs.nix-index-database.comma.enable = true;
}
