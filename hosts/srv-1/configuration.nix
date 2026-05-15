{ pkgs, ... }:
{
  imports = [
    ./network-vars.nix
    ./disk-config.nix
    ./hardware-configuration.nix
    ./boot.nix
    ./network.nix
    ../../modules/nixos/common
    ./secrets
    ./services
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
