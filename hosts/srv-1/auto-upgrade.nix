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
    # Hors fenêtre, un upgrade qui demande un reboot devient l'entrée de boot par défaut sans
    # être activé (appliqué au prochain reboot, quel qu'il soit), et l'unité sort en succès.
    rebootWindow = {
      # 03:59 : le module teste `heure > lower` strictement, 04:00 raterait un run à 04:00.
      lower = "03:59";
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
