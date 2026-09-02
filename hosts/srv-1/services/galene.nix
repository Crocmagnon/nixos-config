{
  config,
  pkgs,
  lib,
  ...
}:
let
  turnPort = 1194; # default but in a variable so we can use it in the firewall configuration
  udpMin = 40000;
  udpMax = 60000;
  udpRange = "${toString udpMin}-${toString udpMax}";

  # One op user per group, named after the group, mapped to its hashed password.
  # No wildcard user, so these are the only usernames that can connect.
  # To change a password:
  #   galenectl hash-password -type pbkdf2 -iterations 600000 -password '<new password>'
  # and paste the JSON it prints as that user's value below.
  opPasswords = {
    Claire = ''{"type":"pbkdf2","hash":"sha-256","key":"5a55c8dd64753232fb6078ff89740b34c3e46c3a6b7b5619d42727525f4b1124","salt":"b68bbafb67a60ce0","iterations":600000}'';
    Didier = ''{"type":"pbkdf2","hash":"sha-256","key":"5a55c8dd64753232fb6078ff89740b34c3e46c3a6b7b5619d42727525f4b1124","salt":"b68bbafb67a60ce0","iterations":600000}'';
    Tom = ''{"type":"pbkdf2","hash":"sha-256","key":"5a55c8dd64753232fb6078ff89740b34c3e46c3a6b7b5619d42727525f4b1124","salt":"b68bbafb67a60ce0","iterations":600000}'';
    Maxime = ''{"type":"pbkdf2","hash":"sha-256","key":"5a55c8dd64753232fb6078ff89740b34c3e46c3a6b7b5619d42727525f4b1124","salt":"b68bbafb67a60ce0","iterations":600000}'';
    Nicolas = ''{"type":"pbkdf2","hash":"sha-256","key":"5a55c8dd64753232fb6078ff89740b34c3e46c3a6b7b5619d42727525f4b1124","salt":"b68bbafb67a60ce0","iterations":600000}'';
    Fleur = ''{"type":"pbkdf2","hash":"sha-256","key":"5a55c8dd64753232fb6078ff89740b34c3e46c3a6b7b5619d42727525f4b1124","salt":"b68bbafb67a60ce0","iterations":600000}'';
  };

  groupFiles = lib.mapAttrsToList (
    name: password:
    pkgs.writeTextDir "${name}.json" ''
      {
        "public": true,
        "allow-recording": false,
        "users": {
          "${name}": {
            "password": ${password},
            "permissions": "op"
          }
        }
      }
    ''
  ) opPasswords;
in
{
  services.galene = {
    enable = true;
    httpAddress = "127.0.0.1";
    httpPort = 8003;
    turnAddress = ":${toString turnPort}";
    groupsDir = pkgs.symlinkJoin {
      name = "galene-groupdir";
      paths = groupFiles;
    };
  };

  systemd.tmpfiles.rules = [
    "L+ ${config.services.galene.dataDir}/config.json 0640 galene galene - ${./galene-config.json}"
  ];

  # overridden to add the -udp-range option
  systemd.services.galene.serviceConfig.ExecStart = lib.mkForce ''
    ${config.services.galene.package}/bin/galene \
    ${lib.optionalString (config.services.galene.insecure) "-insecure"} \
    -http ${config.services.galene.httpAddress}:${toString config.services.galene.httpPort} \
    -turn ${config.services.galene.turnAddress} \
    -data ${config.services.galene.dataDir} \
    -groups ${config.services.galene.groupsDir} \
    -recordings ${config.services.galene.recordingsDir} \
    -udp-range ${udpRange} \
    -static ${config.services.galene.staticDir}'';

  # galene expects https traffic and uses a self-signed certificate
  services.caddy.virtualHosts."visio.g4b.ovh".extraConfig = ''
    import common_headers
    reverse_proxy https://localhost:${toString config.services.galene.httpPort} {
      transport http {
        tls
        tls_insecure_skip_verify
      }
    }
  '';

  # make galenectl available on the system path
  environment.systemPackages = [
    config.services.galene.package
  ];

  # open network ports, see https://galene.org/galene-install.html#running-behind-a-firewall
  networking.firewall = {
    allowedTCPPorts = [ turnPort ];
    allowedUDPPorts = [ turnPort ];
    allowedUDPPortRanges = [
      {
        from = udpMin;
        to = udpMax;
      }
    ];
  };
}
