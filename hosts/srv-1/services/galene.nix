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
    Claire = ''{"type":"pbkdf2","hash":"sha-256","key":"88e7b282b1e8e22fa7f591ebacbd1c2b600c577f497fee03384d23c454d28a93","salt":"1c2a6ae00381c4b2","iterations":600000}'';
    Didier = ''{"type":"pbkdf2","hash":"sha-256","key":"e08e599e1c721248422115a9ebef9d84f1fb2483c2d0dfb6af12747a97dc4289","salt":"5f7a005ad74028c6","iterations":600000}'';
    Tom = ''{"type":"pbkdf2","hash":"sha-256","key":"9e9f134b6852fe4b8d93d5788f11c378dd113ee6948791816a0c407559c175a7","salt":"939866d3e5594401","iterations":600000}'';
    Maxime = ''{"type":"pbkdf2","hash":"sha-256","key":"7761e235eb21fdb23ec2ce3d49936ccfa8c06c477daed8d96f78125d9032fc6a","salt":"9ce19c755db8a588","iterations":600000}'';
    Nicolas = ''{"type":"pbkdf2","hash":"sha-256","key":"9db21bde0d287bc2b427bbc7d5d6f46f99940518d9853b4c1dcc73d54d02151b","salt":"8390e0f76340742c","iterations":600000}'';
    Fleur = ''{"type":"pbkdf2","hash":"sha-256","key":"218a717adc2519c59eb0540cbc94194f498bcaf145da813085fdab8ae058bc6a","salt":"cde1918ab1b6a09b","iterations":600000}'';
    "Valérie" =
      ''{"type":"pbkdf2","hash":"sha-256","key":"80c3024255376851757e08a24a5d2efcd7e5207c970f986e529600347bc5302a","salt":"8cc1b42c1eb3be47","iterations":600000}'';
    "Anne-Laure" =
      ''{"type":"pbkdf2","hash":"sha-256","key":"00e1e7263362aee9061eed74d126e490ff26e1d0f920f70941e6c2f978c9eda2","salt":"8357948332dfaa86","iterations":600000}'';
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
