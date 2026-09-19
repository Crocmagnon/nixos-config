# Réglages liés au KVM (framework-gab derrière un switch clavier/écran/souris).
{ ... }:
{
  # Réveil de la veille s2idle par le clavier/souris derrière le KVM. Le noyau crée
  # chaque device USB avec power/wakeup=disabled ; le KVM détache/rattache le hub à
  # chaque bascule, donc un réglage ponctuel ne survit pas -- il faut la règle udev.
  # Sans effet une fois la machine hibernée (cf. suspend-then-hibernate.nix).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usb", ATTR{power/wakeup}="enabled"
  '';

  # Capot fermé : ne rien faire sur secteur, pour pouvoir basculer le KVM vers une
  # autre machine sans avoir à rouvrir l'écran. Sur batterie on garde la veille.
  home-manager.users.gaugendre.programs.plasma.powerdevil = {
    AC.whenLaptopLidClosed = "doNothing";
    battery.whenLaptopLidClosed = "sleep";
    lowBattery.whenLaptopLidClosed = "sleep";
  };
}
