{ ... }:
{
  # Applique chaque nuit le main de GitHub, avec son flake.lock : les inputs n'avancent
  # que par la PR hebdo du workflow update-flake-lock, mergée à la main.
  system.autoUpgrade = {
    enable = true;
    flake = "github:Crocmagnon/nixos-config";
    dates = "04:00";
    randomizedDelaySec = "30min";
    # Reboot seulement si kernel, initrd ou modules changent ; sinon simple switch.
    allowReboot = true;
    # Hors fenêtre, un upgrade qui demande un reboot est sauté (rien n'est appliqué)
    # et l'unité sort quand même en succès : seul le journal le dit.
    rebootWindow = {
      lower = "04:00";
      upper = "06:00";
    };
  };

  systemd.services.nixos-upgrade = {
    # Attend un restic en cours : il arrête des services que le switch relancerait.
    after = [ "restic-backups-local.service" ];
    wants = [ "healthchecks@nixos-upgrade:start.service" ];
    onSuccess = [ "healthchecks@nixos-upgrade:success.service" ];
    onFailure = [ "healthchecks@nixos-upgrade:failure.service" ];
  };
}
