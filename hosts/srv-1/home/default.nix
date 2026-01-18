{ inputs, ... }:
{
  home-manager.users.gaugendre = {
    imports = [
      ../../../home/gaugendre/home.nix
      inputs.catppuccin.homeModules.catppuccin
    ];
  };

  home-manager.users.root = {
    imports = [
      ../../../home/root/home.nix
      inputs.catppuccin.homeModules.catppuccin
    ];
  };
}
