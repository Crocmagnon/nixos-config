{ config, ... }:
let
  servicesToStop = [
    # Paperless
    "paperless-consumer.service"
    "paperless-scheduler.service"
    "paperless-task-queue.service"
    "paperless-web.service"
    # Servarr
    "jellyfin.service"
    "prowlarr.service"
    "sonarr.service"
    "radarr.service"
    "transmission.service"
    # Calibre
    "calibre-web.service"
  ];
in
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
        "/var/lib/private" # contains prowlarr data
        "/var/lib/transmission"
        "/var/lib/jellyfin"
        "/var/lib/calibre-web"
        # "/var/lib/media"
      ];
      exclude = [
        # Copie locale jetable de pCloud, resynchronisable par
        # calibre-library-sync et déjà sauvegardée vers OVH par pcloud-sync.
        # Seul app.db (comptes, étagères, progression) mérite le backup.
        "/var/lib/calibre-web/library"
      ];
      repository = "s3:https://s3.sbg.io.cloud.ovh.net/restic-srv-1-gaugendre";
      pruneOpts = [
        # Par défaut forget groupe par host+paths : chaque changement de
        # `paths` laissait l'ancien groupe figé, conservé indéfiniment.
        "--group-by host"
        "--keep-within-daily 7d"
        "--keep-within-weekly 1m"
      ];
      timerConfig = {
        OnCalendar = "02:00";
        Persistent = true;
      };
      progressFps = 0.01; # every 100s

      # Services are stopped via systemd conflicts (see below)

      backupCleanupCommand = ''
        # Restart services after backup. --no-block : ces services sont en conflicts
        # avec ce job, leur démarrage attend donc qu'il soit arrêté ; en attendant ici,
        # le post-stop s'interbloquait jusqu'au timeout (90 s) et le job finissait en échec.
        systemctl start --no-block ${builtins.concatStringsSep " " servicesToStop}
      '';
    };
  };

  # Extend the systemd service to stop conflicting services during backup
  systemd.services.restic-backups-local = {
    conflicts = servicesToStop;
    after = servicesToStop;
    # Le module lance backup puis `forget --prune` dans la même unité : une
    # seule sonde couvre les deux.
    wants = [ "healthchecks@restic-backup:start.service" ];
    onSuccess = [ "healthchecks@restic-backup:success.service" ];
    onFailure = [ "healthchecks@restic-backup:failure.service" ];
  };

}
