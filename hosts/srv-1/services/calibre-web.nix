# calibre-web en LECTURE SEULE : pCloud est la source de vérité, la lib est
# éditée depuis Calibre desktop et `calibre-library-sync` en tire une copie
# locale à sens unique (toute modif locale est écrasée au prochain sync).
#
# Passage en lecture/écriture, le jour où on veut uploader depuis l'UI :
#   1. options.enableBookUploading = true (+ enableBookConversion et
#      enableKepubify pour l'envoi Kindle/Kobo — attention, enableBookConversion
#      tire tout calibre, ~1 Go).
#   2. `rclone sync` -> `rclone bisync` dans l'ExecStart ci-dessous, puis un
#      `rclone bisync --resync <src> <dst>` lancé une fois à la main pour
#      initialiser l'état bisync.
#   3. Retirer /var/lib/calibre-web/library des `exclude` de restic.nix : la
#      copie locale n'est alors plus jetable.
# Piège : si metadata.db bouge des deux côtés entre deux runs, bisync produit
# des .conflict1/.conflict2 à trancher à la main. Tant qu'on ajoute d'un seul
# côté à la fois, ça n'arrive pas.
{ config, pkgs, ... }:
let
  libraryDir = "/var/lib/calibre-web/library";
in
{
  services.calibre-web = {
    enable = true;
    listen.ip = "127.0.0.1";
    listen.port = 8005;
    options.calibreLibrary = libraryDir;
  };

  # Le module a un ExecStartPre qui échoue si metadata.db est absent : dépendre
  # du sync règle le bootstrap au premier déploiement. `wants` et non
  # `requires` pour que pCloud injoignable ne bloque pas le démarrage.
  systemd.services.calibre-web.wants = [ "calibre-library-sync.service" ];

  systemd.timers.calibre-library-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "04:00";
    timerConfig.Persistent = true;
  };

  systemd.services.calibre-library-sync = {
    restartIfChanged = false;
    wantedBy = [ "multi-user.target" ];
    before = [ "calibre-web.service" ];
    wants = [
      "network-online.target"
      "healthchecks@sync-calibre:start.service"
    ];
    after = [ "network-online.target" ];
    onSuccess = [ "healthchecks@sync-calibre:success.service" ];
    onFailure = [ "healthchecks@sync-calibre:failure.service" ];
    environment = {
      RCLONE_CONFIG = config.age.secrets."rclone-config".path;
    };
    serviceConfig = {
      Type = "oneshot";
      User = "calibre-web";
      Group = "calibre-web";
      StateDirectory = "calibre-web";
      ExecStart = "${pkgs.rclone}/bin/rclone sync --stats=30m --stats-log-level=NOTICE pcloud-gab:/Sync/Lecture/calibre-library ${libraryDir}";
      # Sans ça calibre-web garde l'ancien inode de metadata.db et n'affiche
      # pas les livres qui viennent d'arriver. Le `+` fait tourner cette ligne
      # en root (User=calibre-web n'a pas le droit de piloter systemd), et
      # --no-block évite l'interblocage au boot où calibre-web nous attend déjà.
      ExecStartPost = "+${pkgs.systemd}/bin/systemctl --no-block try-restart calibre-web.service";
    };
  };

  services.caddy.virtualHosts."books.srv-1.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:${toString config.services.calibre-web.listen.port}
  '';
}
