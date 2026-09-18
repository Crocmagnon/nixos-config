# Bascule automatique Catppuccin latte/mocha, pilotée par la couleur de fond du
# terminal. Ce module est partagé par gaugendre et root sur toutes les machines :
# c'est ce qui fait que les sessions SSH vers srv-1 suivent aussi, puisque la
# requête OSC 11 traverse sshd comme n'importe quels octets sur le pty.
#
# Voir docs/superpowers/specs/2026-09-18-terminal-theme-auto-switch-design.md
{
  config,
  lib,
  pkgs,
  ...
}:
let
  sources = config.catppuccin.sources;
in
{
  # bat 0.26 sait choisir seul entre un thème clair et un thème sombre en
  # interrogeant le fond du terminal. Le module amont ne poserait qu'une saveur.
  catppuccin.bat.enable = false;

  programs.bat = {
    config = {
      theme = "auto";
      theme-dark = "Catppuccin Mocha";
      theme-light = "Catppuccin Latte";
    };
    themes = {
      "Catppuccin Mocha" = {
        src = sources.bat;
        file = "Catppuccin Mocha.tmTheme";
      };
      "Catppuccin Latte" = {
        src = sources.bat;
        file = "Catppuccin Latte.tmTheme";
      };
    };
  };
}
