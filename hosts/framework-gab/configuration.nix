{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./fingerprint.nix
    ./power-monitoring.nix
    ./suspend-then-hibernate.nix
    ../../modules/nixos/common
    ../../modules/nixos/desktop
  ];

  hardware.bluetooth.enable = true;
  networking.hostName = "framework-gab";

  # Réveil de la veille s2idle par le clavier/souris derrière le KVM. Le noyau crée
  # chaque device USB avec power/wakeup=disabled ; le KVM détache/rattache le hub à
  # chaque bascule, donc un réglage ponctuel ne survit pas -- il faut la règle udev.
  # Sans effet une fois la machine hibernée (cf. suspend-then-hibernate.nix).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usb", ATTR{power/wakeup}="enabled"
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
