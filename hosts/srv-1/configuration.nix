{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  ipv6 = "2001:41d0:700:114f::1";
  ipv6gw = "2001:41d0:0700:11ff:00ff:00ff:00ff:00ff";
  interface = "eno1";
  tailscaleIp = "100.108.113.85 [fd7a:115c:a1e0::2501:7166]";
in
{
  _module.args.tailscaleIp = tailscaleIp;
  imports = [
    ./disk-config.nix
    ./users.nix
    ./hardware-configuration.nix
    ./services/caddy.nix
    ./services/miniflux.nix
    ./services/test-headers.nix
    ./services/wallabag.nix
    ./secrets
    ./services/filebeat.nix
    ./services/paperless.nix
    ./services/healthchecks.nix
    ./services/pcloud-sync.nix
    ./services/servarr.nix
    ./services/restic.nix
    ./services/tailscale.nix
    ./services/galene.nix
    ./services/stirling-pdf.nix
    # ./services/ftp.nix
    ../../modules/nixos/common
  ];

  boot = {
    supportedFilesystems = [ "btrfs" ];

    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";

        mirroredBoots = [
          {
            devices = [ "nodev" ];
            path = "/boot";
            efiSysMountPoint = "/boot";
          }
          {
            devices = [ "nodev" ];
            path = "/boot-fallback";
            efiSysMountPoint = "/boot-fallback";
          }
        ];
      };

      # efi.canTouchEfiVariables = true;
    };
  };

  # Enable periodic scrubbing to check for data corruption
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  services.openssh.enable = true;

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
    helix
    wget
  ];

  system.stateVersion = "25.11";
}
