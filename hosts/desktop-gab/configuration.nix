{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common
    ../../modules/nixos/desktop
    ../../modules/nixos/desktop/virt.nix
  ];

  hardware.bluetooth.enable = true;
  networking.hostName = "desktop-gab";

  # simpledrm ne gère pas le hotplug DisplayPort : sans amdgpu dans l'initrd,
  # allumer l'écran une fois arrivé sur l'invite LUKS laisse le moniteur noir.
  boot.initrd.kernelModules = [ "amdgpu" ];

  services.hardware.openrgb.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
