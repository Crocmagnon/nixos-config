{ inputs, ... }:
{
  home-manager.users.gaugendre = {
    imports = [
      ../../../home/gaugendre/home.nix
      ./krunner-autostart.nix
      ./email.nix
      ./ai-agents.nix
      inputs.catppuccin.homeModules.catppuccin
    ];
  };
}
