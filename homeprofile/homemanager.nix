user: sources:
{ ... }:
{
  imports = [
    (import "${sources.home-manager}/nixos")
  ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${user} = {
      imports = [
        ../homeprofile/home.nix
        (sources.catppuccin + "/modules/home-manager")
      ];
    };
    backupFileExtension = "hm-bkp";
  };
}
