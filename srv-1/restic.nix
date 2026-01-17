{ config, ... }:
{

  services.restic.backups = {
    local = {
      initialize = true;
      createWrapper = true;
      environmentFile = config.age.secrets."s3-restic-srv-1-creds".path;
      passwordFile = config.age.secrets."restic-password".path;
      paths = [
        "/var/lib/paperless"
        "/var/lib/radarr"
        "/var/lib/sonarr"
        "/var/lib/prowlarr"
        "/var/lib/transmission"
        "/var/lib/syncthing"
        "/var/lib/jellyfin"
        "/var/lib/media"
      ];
      repository = "s3:https://s3.sbg.io.cloud.ovh.net/restic-srv-1-gaugendre";
      pruneOpts = [
        "--keep-within-daily 7d"
        "--keep-within-weekly 1m"
      ];
      timerConfig = {
        OnCalendar = "02:00";
        Persistent = true;
      };
      progressFps = 0.01; # every 100s
    };
  };

}
