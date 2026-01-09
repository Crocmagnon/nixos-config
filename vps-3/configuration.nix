{
  modulesPath,
  lib,
  pkgs,
  config,
  ...
}:
let
  ipv6 = "2001:41d0:305:2100::a8ac";
  ipv6gw = "2001:41d0:305:2100::1";
  interface = "ens3";
in
{
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
    ./filebeat.nix
    ./paperless.nix
    ./healthchecks.nix
    ./pcloud-sync.nix
    ../common/save-disk.nix
  ];

  hardware.facter.reportPath = ./facter.json;
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  services.openssh.enable = true;
  time.timeZone = "Europe/Paris";
  networking = {
    hostName = "vps-3";
    enableIPv6 = true;
    useNetworkd = lib.mkDefault true;
    firewall = {
      allowedTCPPorts = [
        80
        443
      ];
      trustedInterfaces = [ "tailscale0" ];
    };
    interfaces."${interface}".ipv6 = {
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
    defaultGateway6 = {
      address = ipv6gw;
      interface = interface;
    };
  };
  services.fail2ban.enable = true;

  environment.systemPackages =
    with pkgs;
    map lib.lowPrio [
      curl
      gitMinimal
      helix
      wget
    ];

  programs.fish.enable = true;
  documentation.man.generateCaches = false; # speeds up rebuild by skiping "building man-cache", enabled by default by fish

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    authKeyFile = config.age.secrets."tailscale-auth-key".path;
    authKeyParameters.ephemeral = false;
    authKeyParameters.preauthorized = true;
    extraUpFlags = [
      "--ssh"
      "--advertise-exit-node"
      "--accept-dns"
      "--accept-routes"
      "--advertise-tags=tag:nix,tag:home"
    ];
  };

  services.restic.backups = {
    local = {
      initialize = true;
      createWrapper = true;
      environmentFile = config.age.secrets."paperless-s3-creds".path;
      passwordFile = config.age.secrets."restic-password".path;
      paths = [
        "/var/lib/paperless/export"
      ];
      repository = "s3:https://s3.sbg.io.cloud.ovh.net/restic-vps-3-gaugendre";
      pruneOpts = [
        "--keep-within-daily 7d"
        "--keep-within-weekly 1m"
      ];
      timerConfig = {
        OnCalendar = "02:00";
        Persistent = true;
      };
    };
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
