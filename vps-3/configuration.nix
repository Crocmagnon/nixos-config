{
  inputs,
  modulesPath,
  lib,
  pkgs,
  config,
  ...
} : {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./caddy.nix
    ./miniflux.nix
    ./users.nix
    ./test-headers.nix
    ./secrets
    ./facter.nix
    ../common/save-disk.nix
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;
  networking = {
    hostName = "vps-3";
    firewall.allowedTCPPorts = [80 443];
  };

  # check first here if a package has options : https://search.nixos.org/options
  # before adding to systemPackages.
  # systemPackages barely installs a package, enabling with options if available
  # handles more things (completions for fish for example, or systemd units, etc)
  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.helix
    pkgs.wget
  ];

  programs.fish.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  system.stateVersion = "25.11";
}
