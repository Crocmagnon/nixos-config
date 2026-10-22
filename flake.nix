{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix/release-26.05";
      # Pas de `inputs.nixpkgs.follows` : laisser catppuccin utiliser son nixpkgs
      # épinglé, sinon whiskers/thèmes sont rebuild (cache miss sur catppuccin.cachix.org).
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    downloader = {
      url = "git+https://github.com/Crocmagnon/downloader-go";
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
      disko,
      agenix,
      home-manager,
      downloader,
      nix-index-database,
      ...
    }@inputs:
    let
      mkHost =
        {
          extraModules ? [ ],
          extraOverlays ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = [
                (import ./overlays/unstable-packages.nix { inherit nixpkgs-unstable; })
              ]
              ++ extraOverlays;
            }
          ]
          ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        # nixos-anywhere --flake .#srv-1 --generate-hardware-config nixos-generate-config ./hardware-configuration.nix <hostname>
        srv-1 = mkHost {
          extraModules = [
            disko.nixosModules.disko
            agenix.nixosModules.default
            ./hosts/srv-1/configuration.nix
          ];
          extraOverlays = [
            (import ./overlays/playwright-downloader.nix { inherit downloader; })
          ];
        };
      };
    };
}
