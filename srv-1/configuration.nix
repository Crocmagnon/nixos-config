{
  lib,
  pkgs,
  ...
}:
let
  ipv6 = "2001:41d0:700:114f::1";
  ipv6gw = "2001:41d0:0700:11ff:00ff:00ff:00ff:00ff";
  interface = "eno1";
in
{
  imports = [
    ./disk-config.nix
    ./users.nix
    ./hardware-configuration.nix
    ./caddy.nix
    ./miniflux.nix
    ./test-headers.nix
    ./wallabag.nix
    ./secrets
    ./filebeat.nix
    ./paperless.nix
    ./healthchecks.nix
    ./pcloud-sync.nix
    ./servarr.nix
    ./restic.nix
    ./tailscale.nix
    ../common/save-disk.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  services.openssh.enable = true;
  time.timeZone = "Europe/Paris";
  networking = {
    hostName = "srv-1";
    enableIPv6 = true;
    useNetworkd = lib.mkDefault true;
    firewall = {
      allowedTCPPorts = [
        80
        443
      ];
      trustedInterfaces = [ "tailscale0" ];
    };
    interfaces."${interface}" = {
      useDHCP = true;
      ipv6 = {
        addresses = [
          {
            address = ipv6;
            prefixLength = 128;
          }
        ];
        routes = [
          {
            address = ipv6gw;
            prefixLength = 64;
          }
        ];
      };
    };
    defaultGateway6 = {
      address = ipv6gw;
      interface = interface;
    };
  };
  services.fail2ban.enable = true;

  environment.systemPackages = with pkgs; [
    curl
    gitMinimal
    helix
    wget
  ];

  programs.fish.enable = true;
  documentation.man.generateCaches = false; # speeds up rebuild by skiping "building man-cache", enabled by default by fish

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  programs.nh = {
    enable = true;
  };

  system.stateVersion = "25.11";
}
