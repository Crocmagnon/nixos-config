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

  catppuccin.enable = true;

  programs.bash.enable = true;
}
