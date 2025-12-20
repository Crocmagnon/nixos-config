{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-release.url = "github:nixos/nixpkgs/release-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "";
    };

  };

  outputs = {
    nixpkgs,
    nixpkgs-release,
    nixos-facter-modules,
    disko,
    agenix,
    home-manager,
    catppuccin,
    ...
  }:
  {
    nixosConfigurations.framework-gab = nixpkgs.lib.nixosSystem {
      modules = [
        ./framework-gab/configuration.nix
        catppuccin.nixosModules.catppuccin
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.gaugendre = {
              imports = [
                ./homeprofile/home.nix
                catppuccin.homeModules.catppuccin
              ];
            };
            backupFileExtension = "hm-bkp";
          };
        }
      ];
    };

    # nixos-anywhere --flake .#vps-3 --generate-hardware-config nixos-facter facter.json <hostname>
    nixosConfigurations.vps-3 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = let
        system = "x86_64-linux";
      in {
        pkgs-release = import nixpkgs-release {
          inherit system;
          config.allowUnfree = true;
        };
      };
      modules = [
        disko.nixosModules.disko
        agenix.nixosModules.default
        nixos-facter-modules.nixosModules.facter
        ./vps-3/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.gaugendre = {
              imports = [
                ./homeprofile/home.nix
                ./vps-3/home.nix
                catppuccin.homeModules.catppuccin
              ];
            };
            backupFileExtension = "hm-bkp";
          };
        }
      ];
    };
  };
}
