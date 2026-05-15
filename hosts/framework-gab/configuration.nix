{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common
    ../../modules/nixos/desktop
  ];

  hardware.bluetooth.enable = true;
  networking.hostName = "framework-gab";

  # https://github.com/NixOS/nixpkgs/issues/239770
  security.pam.services.login.fprintAuth = false;

  services.fprintd = {
    enable = true;
    #  tod.enable = true;
    #  tod.driver = pkgs.libfprint-2-tod1-goodix;
  };

  # Fix fprintd recognizing fingerprint after suspend
  powerManagement.powerDownCommands = ''
    ${pkgs.systemd}/bin/systemctl stop fprintd.service 2>/dev/null || true
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
