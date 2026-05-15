{ inputs, ... }:
{
  home-manager.users.gaugendre = {
    imports = [
      ../../home/gaugendre/desktop
      inputs.plasma-manager.homeModules.plasma-manager
    ];
  };
}
