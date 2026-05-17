{ pkgs, lib, ... }:
{
  catppuccin.sddm.enable = false;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "gaugendre";
  };

  # Auto-unlock kwallet on SDDM autologin: inherit the kernel keyring populated
  # at boot by systemd-cryptsetup, then feed the LUKS passphrase into PAM_AUTHTOK
  # so pam_kwallet5 can open the wallet without prompting.
  # https://wiki.archlinux.org/title/KDE_Wallet#Using_SDDM_autologin_and_LUKS_encryption
  systemd.services.display-manager.serviceConfig.KeyringMode = "inherit";

  # Original:
  # https://github.com/NixOS/nixpkgs/blob/d7a713c0b7e47c908258e71cba7a2d77cc8d71d5/nixos/modules/services/display-managers/sddm.nix#L391-L402
  security.pam.services.sddm-autologin.text = lib.mkForce ''
    auth     requisite pam_nologin.so
    auth     optional  ${pkgs.systemd}/lib/security/pam_systemd_loadkey.so
    auth     optional  ${pkgs.kdePackages.kwallet-pam}/lib/security/pam_kwallet5.so
    auth     required  pam_succeed_if.so uid >= 1000 quiet
    auth     required  pam_permit.so

    account  include   sddm

    password include   sddm

    session  include   sddm
  '';
}
