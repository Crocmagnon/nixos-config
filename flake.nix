{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    playwright = {
      url = "github:pietdevries94/playwright-web-flake/1.52.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      inputs.playwright.follows = "playwright";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      nixos-hardware,
      playwright,
      disko,
      agenix,
      home-manager,
      catppuccin,
      downloader,
      ...
    }:
    {
      nixosConfigurations.framework-gab = nixpkgs.lib.nixosSystem {
        modules = [
          ./framework-gab/configuration.nix
          nixos-hardware.nixosModules.framework-amd-ai-300-series
          catppuccin.nixosModules.catppuccin
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.gaugendre = {
                imports = [
                  ./homeprofile/home.nix
                  ./homeprofile/krunner-autostart.nix
                  ./framework-gab/email.nix
                  ./framework-gab/ai-agents.nix
                  catppuccin.homeModules.catppuccin
                ];
              };
              backupFileExtension = "hm-bkp";
            };
          }
        ];
      };

      # nixos-anywhere --flake .#srv-1 --generate-hardware-config nixos-generate-config ./hardware-configuration.nix <hostname>
      nixosConfigurations.srv-1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          ./srv-1/configuration.nix
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
          {
            nixpkgs.overlays = [
              (final: prev: {
                inherit (playwright.packages.x86_64-linux) playwright-driver;
                inherit (downloader.packages.x86_64-linux) downloader-go;
              })
              (final: prev: {
                inherit
                  (import nixpkgs-unstable {
                    system = final.system;
                    config.allowUnfree = true;
                  })
                  btop
                  ;
              })
            ];
          }
        ];
      };
    };
}
