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
  _module.args = {
      network = {
        inherit ipv6 ipv6gw interface tailscaleIp;
      };
  };
  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
    ./boot.nix
    ./network.nix
    ../../modules/nixos/common
    ./secrets

    ./services/caddy.nix
    ./services/miniflux.nix
    ./services/test-headers.nix
    ./services/wallabag.nix
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
  ];

  # Enable periodic scrubbing to check for data corruption
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  environment.systemPackages = with pkgs; [
    curl
    helix
    wget
  ];

  # allow deploying config from non-root user
  nix.settings.trusted-users = [
    "gaugendre"
  ];

  system.stateVersion = "25.11";
}
