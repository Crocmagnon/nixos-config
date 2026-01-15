{ config, pkgs, ... }:
{
  systemd.timers.pcloud-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "03:00";
    timerConfig.Persistent = true;
  };

  systemd.services.pcloud-sync = {
    restartIfChanged = false;
    wants = [
      "network-online.target"
      "healthchecks@sync-pcloud:start.service"
    ];
    after = [ "network-online.target" ];
    onSuccess = [ "healthchecks@sync-pcloud:success.service" ];
    onFailure = [ "healthchecks@sync-pcloud:failure.service" ];
    environment = {
      RCLONE_CONFIG = config.age.secrets."rclone-config".path;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        ''${pkgs.rclone}/bin/rclone sync --stats=30m --stats-log-level=NOTICE --transfers=10 --checksum pcloud-gab:/ ovh-pcloud-sync:pcloud-sync-gaugendre/gabriel/''
        ''${pkgs.rclone}/bin/rclone sync --stats=30m --stats-log-level=NOTICE --transfers=10 --checksum pcloud-claire:/ ovh-pcloud-sync:pcloud-sync-gaugendre/claire/ --exclude "/Photos en commun/**" --exclude "/Partage Claire Gab/**"''
      ];
    };
  };
}
