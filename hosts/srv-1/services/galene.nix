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
in
{
  services.galene = {
    enable = true;
    httpAddress = "127.0.0.1";
    httpPort = 8003;
    turnAddress = ":${toString turnPort}";
    groupsDir = pkgs.writeTextFile {
      name = "galene-groupdir";
      destination = "/meet.json";
      text = ''
        {
          "allow-recording": true,
          "auto-subgroups": true,
          "wildcard-user": {
            "password": {"type":"pbkdf2","hash":"sha-256","key":"5a55c8dd64753232fb6078ff89740b34c3e46c3a6b7b5619d42727525f4b1124","salt":"b68bbafb67a60ce0","iterations":600000},
            "permissions": "op"
          },
          "public": true
        }
      '';
    };
  };

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
