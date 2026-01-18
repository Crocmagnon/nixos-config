{ inputs, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.gaugendre = {
      imports = [
        ../../../home/gaugendre/home.nix
        ./krunner-autostart.nix
        ./email.nix
        ./ai-agents.nix
        inputs.catppuccin.homeModules.catppuccin
      ];
    };
    backupFileExtension = "hm-bkp";
  };
}
