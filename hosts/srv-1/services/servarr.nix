{
  config,
  lib,
  pkgs,
  ...
}:
let
  mediaDir = "/var/lib/media";
  # Login des *arr remplacé par le portail Authelia (`import sso`). `External` désactive toute auth
  # applicative (même la clé d'API est servie par /initialize.json) : ils ne doivent écouter que
  # sur localhost, sinon tout le tailnet (trustedInterfaces) les atteint sans portail. Les trois
  # réglages vont ensemble, d'où ce bloc commun.
  arrs = [
    "prowlarr"
    "sonarr"
    "radarr"
  ];
  arrBase = {
    enable = true;
    settings.auth.method = "External";
    settings.server.bindaddress = "127.0.0.1";
  };
  transmissionCredFile = config.age.secrets."transmission-credentials".path;
in
{
  # Create shared media group for all services
  users.groups.media = {
    members = [
      "gaugendre"
      config.services.sonarr.user
      config.services.radarr.user
      config.services.jellyfin.user
      # config.services.prowlarr.user # this setting doesn't exist
      config.services.transmission.user
    ];
  };

  # Create media directory structure with proper permissions
  systemd.tmpfiles.rules = [
    "d ${mediaDir} 0775 ${config.services.transmission.user} media - -"
    "d ${mediaDir}/downloads 0775 ${config.services.transmission.user} media - -"
    "d ${mediaDir}/downloads/incomplete 0775 ${config.services.transmission.user} media - -"
    "d ${mediaDir}/tv 0775 ${config.services.sonarr.user} media - -"
    "d ${mediaDir}/movies 0775 ${config.services.radarr.user} media - -"
    "d ${mediaDir}/other-photos-videos 0775 ${config.services.jellyfin.user} media - -"
  ];

  services.jellyfin = {
    enable = true;
    group = "media";
  };
  # Jellyfin écoute sur toutes les interfaces par défaut, donc sur tout le tailnet (interface de
  # confiance) sans passer par Caddy. Le module n'a pas d'option : on impose l'adresse d'écoute
  # dans network.xml avant chaque lancement. Découverte automatique (UDP 7359) coupée aussi :
  # Infuse passe par le domaine. En échec fermé : fichier créé s'il manque (réinstallation), et
  # Jellyfin ne démarre pas si le résultat n'est pas celui attendu.
  systemd.services.jellyfin.serviceConfig.ExecStartPre = pkgs.writeShellScript "jellyfin-bind-localhost" ''
    set -eu
    x=${pkgs.xmlstarlet}/bin/xmlstarlet
    f=${config.services.jellyfin.configDir}/network.xml
    [ -e "$f" ] || echo '<NetworkConfiguration><LocalNetworkAddresses /><AutoDiscovery /></NetworkConfiguration>' >"$f"
    $x ed -L \
      -d '/NetworkConfiguration/LocalNetworkAddresses/*' \
      -s '/NetworkConfiguration/LocalNetworkAddresses' -t elem -n string -v 127.0.0.1 \
      -u '/NetworkConfiguration/AutoDiscovery' -v false \
      "$f"
    [ "$($x sel -t -v 'count(/NetworkConfiguration/LocalNetworkAddresses/string)' "$f")" = 1 ]
    [ "$($x sel -t -v '/NetworkConfiguration/LocalNetworkAddresses/string' "$f")" = 127.0.0.1 ]
    [ "$($x sel -t -v '/NetworkConfiguration/AutoDiscovery' "$f")" = false ]
  '';

  services.prowlarr = arrBase; # no `group` option for prowlarr
  services.sonarr = arrBase // {
    group = "media";
  };
  services.radarr = arrBase // {
    group = "media";
  };

  services.transmission = {
    enable = true;
    group = "media";

    # JSON merged into settings.json at start: rpc-username (gaugendre) and rpc-password.
    credentialsFile = transmissionCredFile;
    openFirewall = true;

    settings = {
      # Download directories
      download-dir = "${mediaDir}/downloads";
      incomplete-dir = "${mediaDir}/downloads/incomplete";
      incomplete-dir-enabled = true;

      # RPC (Web UI and API)
      rpc-bind-address = "127.0.0.1";
      rpc-port = 9091;
      rpc-authentication-required = true;
      # Password loaded from credentialsFile

      # Permissions - important for the *arr services to manipulate files
      umask = 2; # Results in 0775 for directories and 0664 for files

      # Performance settings
      download-queue-enabled = true;
      download-queue-size = 5;
      speed-limit-up = 20000;
      speed-limit-up-enabled = true;
      speed-limit-down = 20000;
      speed-limit-down-enabled = true;

      # Peer settings
      peer-port = 51413;
      peer-port-random-on-start = false;
      encryption = 2; # Require encryption

      # Misc
      watch-dir-enabled = false;
      trash-original-torrent-files = false;
      dht-enabled = false;
      lpd-enabled = false;
      pex-enabled = false;

      blocklist-enabled = true;
      blocklist-url = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";
    };
  };

  services.caddy.virtualHosts = {
    "jellyfin.srv-1.augendre.info".extraConfig = ''
      import common_headers
      import internal
      reverse_proxy localhost:8096
    '';

    "transmission.srv-1.augendre.info".extraConfig = ''
      import common_headers
      import internal
      import sso
      # Caddy fournit le mot de passe RPC : pas de second login. caddy-transmission-env contient
      # TRANSMISSION_BASIC_AUTH=<base64 de "gaugendre:<mot de passe>">, le même mot de passe que
      # transmission-credentials : changer l'un, c'est changer l'autre.
      # {env.…} est lu à chaque requête : la valeur n'apparaît pas dans l'admin API de Caddy.
      reverse_proxy localhost:${builtins.toString config.services.transmission.settings.rpc-port} {
        header_up Authorization "Basic {env.TRANSMISSION_BASIC_AUTH}"
      }
    '';
  }
  // lib.listToAttrs (
    map (
      name:
      lib.nameValuePair "${name}.srv-1.augendre.info" {
        extraConfig = ''
          import common_headers
          import internal
          import sso
          reverse_proxy localhost:${toString config.services.${name}.settings.server.port}
        '';
      }
    ) arrs
  );
}
