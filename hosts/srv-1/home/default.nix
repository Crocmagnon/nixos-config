{ inputs, ... }:
{
  home-manager.users.gaugendre = {
    imports = [
      ../../../home/gaugendre/home.nix
      inputs.catppuccin.homeModules.catppuccin
    ];
  };
}
