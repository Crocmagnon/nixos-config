{
  modulesPath,
  lib,
  pkgs,
  ...
} : let
  ipv6 = "2001:41d0:305:2100::a8ac";
  ipv6gw = "2001:41d0:305:2100::1";
  interface = "ens3";
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./caddy.nix
    ./miniflux.nix
    ./users.nix
    ./test-headers.nix
    ./wallabag.nix
    ./secrets
    ./facter.nix
    ./filebeat.nix
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
    enableIPv6 = true;
    useNetworkd = lib.mkDefault true;
    firewall = {
      allowedTCPPorts = [80 443];
      trustedInterfaces = ["tailscale0"];
    };
    interfaces."${interface}".ipv6 = {
      addresses = [{ address = ipv6; prefixLength = 128; }];
      routes = [{ address = ipv6gw; prefixLength = 64; }];
    };
    defaultGateway6 = { address = ipv6gw; interface = interface; };
  };
  services.fail2ban.enable = true;

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

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
