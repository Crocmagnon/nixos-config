# suspend-then-hibernate (framework-gab) — fichier autonome, facile à retirer.
# Après un délai en veille s2idle, la machine hiberne automatiquement -> 0 W.
# Cible la perte batterie sur les longues veilles (nuit/week-end) ; le s2idle est déjà
# quasi optimal (résidence s0ix ~100 %), donc l'hibernation est le seul vrai levier.
# Pour désactiver : retirer ce fichier + sa ligne d'import dans configuration.nix.
{ config, pkgs, ... }:
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

  # 4) Au réveil d'une hibernation (manuelle ou auto) ayant duré > 5 min, lever l'écran de
  #    verrouillage KDE (redondant : passphrase LUKS déjà saisie) -> un seul mot de passe.
  #    Deux gardes : $SYSTEMD_SLEEP_ACTION == "hibernate" (vraie reprise depuis l'image, donc
  #    LUKS saisie ; exclut la veille et l'échec d'hibernation) ET durée > seuil (exclut le
  #    contournement bouton-lockscreen : hiberner puis revenir aussitôt reste verrouillé).
  #    Durée mesurée via un horodatage posé sur "pre" dans /run (tmpfs sauvé dans l'image).
  environment.etc."systemd/system-sleep/unlock-after-hibernate" = {
    mode = "0755";
    source = pkgs.writeShellScript "unlock-after-hibernate" ''
      stamp=/run/unlock-after-hibernate.stamp
      # ponytail: seuil 5 min ; ajuster si un contournement plus lent apparaît.
      threshold=300

      if [ "$1" = pre ]; then
        echo "$EPOCHSECONDS" > "$stamp"
        exit 0
      fi

      [ "$1" = post ] || exit 0
      [ "$SYSTEMD_SLEEP_ACTION" = hibernate ] || exit 0
      [ -r "$stamp" ] || exit 0
      read -r start < "$stamp"; rm -f "$stamp"
      [ $(( EPOCHSECONDS - start )) -ge "$threshold" ] || exit 0

      # Le hook tourne pendant que user.slice est gelée et bloque la fin de reprise :
      # on détache la levée du verrou (systemd-run) pour qu'elle s'exécute une fois la
      # session dégelée, sans bloquer la reprise. Le compositeur KDE se réinitialise et
      # ignore un Unlock trop tôt : on réessaie tant que logind rapporte une session
      # verrouillée, arrêt dès qu'elle ne l'est plus (pas de re-unlock surprise si l'on
      # re-verrouille volontairement). ponytail: plafond 30 s ; relever seq si insuffisant.
      exec ${pkgs.systemd}/bin/systemd-run --collect --unit=unlock-after-hibernate \
        ${pkgs.writeShellScript "do-unlock-after-hibernate" ''
          still_locked() {
            ${pkgs.systemd}/bin/loginctl list-sessions --no-legend \
              | ${pkgs.gawk}/bin/awk '{print $1}' \
              | while read -r s; do
                  ${pkgs.systemd}/bin/loginctl show-session "$s" -p LockedHint --value
                done \
              | ${pkgs.gnugrep}/bin/grep -q '^yes$'
          }
          for _ in $(${pkgs.coreutils}/bin/seq 30); do
            still_locked || break
            ${pkgs.systemd}/bin/loginctl unlock-sessions
            ${pkgs.coreutils}/bin/sleep 1
          done
        ''}
    '';
  };
}
