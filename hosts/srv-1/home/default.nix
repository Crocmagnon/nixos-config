{ inputs, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.gaugendre = {
      imports = [
        ../../../home/gaugendre/home.nix
        inputs.catppuccin.homeModules.catppuccin
      ];
    };
    backupFileExtension = "hm-bkp";
  };
}
