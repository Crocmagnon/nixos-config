{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "";
    };
    downloader = {
      url = "git+https://codeberg.org/Crocmagnon/downloader-go";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      nixos-hardware,
      disko,
      agenix,
      home-manager,
      catppuccin,
      downloader,
      nix-index-database,
      ...
    }@inputs:
    {
      nixosConfigurations.framework-gab = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/framework-gab/configuration.nix
          nixos-hardware.nixosModules.framework-amd-ai-300-series
          catppuccin.nixosModules.catppuccin
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [
              (import ./overlays/unstable-packages.nix { inherit nixpkgs-unstable; })
            ];
          }
        ];
      };

      nixosConfigurations.desktop-gab = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/desktop-gab/configuration.nix
          nixos-hardware.nixosModules.gigabyte-b650
          catppuccin.nixosModules.catppuccin
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [
              (import ./overlays/unstable-packages.nix { inherit nixpkgs-unstable; })
            ];
          }
        ];
      };

      # nixos-anywhere --flake .#srv-1 --generate-hardware-config nixos-generate-config ./hardware-configuration.nix <hostname>
      nixosConfigurations.srv-1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          ./hosts/srv-1/configuration.nix
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [
              (import ./overlays/playwright-downloader.nix { inherit downloader; })
              (import ./overlays/unstable-packages.nix { inherit nixpkgs-unstable; })
            ];
          }
        ];
      };
    };
}
