{
  imports = [
    ./fish.nix
    ./eza.nix
    ./starship.nix
    ./helix.nix
    ./ai-agents.nix
  ];

  programs.nix-index-database.comma.enable = true;
}
