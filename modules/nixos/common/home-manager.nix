{ inputs, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bkp";

    users.gaugendre = {
      imports = [
        ../../../home/gaugendre/home.nix
        inputs.catppuccin.homeModules.catppuccin
        inputs.nix-index-database.homeModules.default
      ];
    };

    users.root = {
      imports = [
        ../../../home/root/home.nix
        inputs.catppuccin.homeModules.catppuccin
        inputs.nix-index-database.homeModules.default
      ];
    };
  };
}
