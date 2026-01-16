{
  config,
  ...
}:
let
  mediaDir = "/var/lib/media";
  transmissionCredFile = config.age.secrets."transmission-credentials".path;
in
{
  # Create shared media group for all services
  users.groups.media = {
    members = [
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
  ];

  services.jellyfin = {
    enable = true;
    group = "media";
  };

  services.prowlarr = {
    enable = true;
    # group = "media"; # this setting doesn't exist
  };

  services.sonarr = {
    enable = true;
    group = "media";
  };

  services.radarr = {
    enable = true;
    group = "media";
  };

  services.transmission = {
    enable = true;
    group = "media";

    # Load credentials from secrets file before starting
    # Expected JSON format: {"rpc-password": "your-password"}
    # The rpc-username defaults to "transmission" in settings below
    credentialsFile = transmissionCredFile;

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

    "prowlarr.srv-1.augendre.info".extraConfig = ''
      import common_headers
      import internal
      reverse_proxy localhost:${builtins.toString config.services.prowlarr.settings.server.port}
    '';

    "sonarr.srv-1.augendre.info".extraConfig = ''
      import common_headers
      import internal
      reverse_proxy localhost:${builtins.toString config.services.sonarr.settings.server.port}
    '';

    "radarr.srv-1.augendre.info".extraConfig = ''
      import common_headers
      import internal
      reverse_proxy localhost:${builtins.toString config.services.radarr.settings.server.port}
    '';

    "transmission.srv-1.augendre.info".extraConfig = ''
      import common_headers
      import internal
      reverse_proxy localhost:${builtins.toString config.services.transmission.settings.rpc-port}
    '';
  };
}
