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

  # gemini-cli renommé en antigravity-cli côté home-manager ; on n'utilise
  # aucun des deux, donc on coupe le thème catppuccin pour éviter le warning.
  catppuccin.gemini-cli.enable = false;
}
