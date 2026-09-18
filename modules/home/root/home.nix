{
  ...
}:
{
  imports = [
    ../shared
  ];

  home.username = "root";
  home.homeDirectory = "/root";
  home.stateVersion = "25.11";

  catppuccin = import ../../../lib/catppuccin.nix;

  programs.bash.enable = true;
}
