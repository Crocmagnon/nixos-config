# suspend-then-hibernate (framework-gab) — fichier autonome, facile à retirer.
# Après un délai en veille s2idle, la machine hiberne automatiquement -> 0 W.
# Cible la perte batterie sur les longues veilles (nuit/week-end) ; le s2idle est déjà
# quasi optimal (résidence s0ix ~100 %), donc l'hibernation est le seul vrai levier.
# Pour désactiver : retirer ce fichier + sa ligne d'import dans configuration.nix.
{ config, ... }:
{
  # 1) Resume depuis le swap LUKS déjà déverrouillé dans l'initrd.
  #    Réutilise le swap déclaré dans hardware-configuration.nix (source unique).
  boot.resumeDevice = (builtins.head config.swapDevices).device;

  # 2) Délai avant la bascule veille(s2idle) -> hibernation.
  #    1min POUR TESTER — à remonter (ex. 120min) une fois le mécanisme validé.
  systemd.sleep.settings.Sleep.HibernateDelaySec = "60min";

  # 3) powerdevil (KDE) fait nativement le suspend-then-hibernate, sur secteur ET batterie.
  #    Déclaré ici via home-manager pour tout garder dans ce seul fichier.
  home-manager.users.gaugendre.programs.plasma.powerdevil = {
    AC.whenSleepingEnter = "standbyThenHibernate";
    battery.whenSleepingEnter = "standbyThenHibernate";
    lowBattery.whenSleepingEnter = "standbyThenHibernate";
  };
}
