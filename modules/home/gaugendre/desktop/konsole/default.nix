{
  config,
  pkgs,
  lib,
  ...
}:
let
  catppuccinKonsole = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "konsole";
    rev = "3b64040e3f4ae5afb2347e7be8a38bc3cd8c73a8";
    sha256 = "sha256-d5+ygDrNl2qBxZ5Cn4U7d836+ZHz77m6/yxTIANd9BU=";
  };
in
{
  home.file."konsole-catppuccin-mocha-theme" = {
    target = ".local/share/konsole/catppuccin-mocha.colorscheme";
    source = "${catppuccinKonsole}/themes/catppuccin-mocha.colorscheme";
  };

  home.file."konsole-catppuccin-latte-theme" = {
    target = ".local/share/konsole/catppuccin-latte.colorscheme";
    source = "${catppuccinKonsole}/themes/catppuccin-latte.colorscheme";
  };

  home.file."konsole-catppuccin-mocha-profile" = {
    target = ".local/share/konsole/catppuccin-mocha.profile";
    source = ./konsole-catppuccin-mocha.profile;
  };

  home.file."konsole-catppuccin-latte-profile" = {
    target = ".local/share/konsole/catppuccin-latte.profile";
    source = ./konsole-catppuccin-latte.profile;
  };
}
