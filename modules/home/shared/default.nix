{
  imports = [
    ./fish.nix
    ./bat.nix
    ./eza.nix
    ./starship.nix
    ./helix.nix
    ./fresh.nix
  ];

  programs.nix-index-database.comma.enable = true;
}
