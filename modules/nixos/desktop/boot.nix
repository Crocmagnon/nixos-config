{
  lib,
  pkgs,
  ...
}:
{
  # L'invite de passphrase LUKS est rendue par plymouth : en latte elle est
  # blanche et aveuglante dans le noir. Mocha ici seulement, le reste du système
  # suit lib/catppuccin.nix.
  catppuccin.plymouth.flavor = "mocha";

  boot = {
    loader = {
      systemd-boot.consoleMode = "max";
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # mkDefault : framework-gab le remplace (cf. suspend-then-hibernate.nix).
    kernelPackages = lib.mkDefault pkgs.linuxPackages;

    # silence first boot output
    consoleLogLevel = 3;
    initrd.verbose = false;
    initrd.systemd.enable = true;
    kernelParams = [
      "quiet"
      "splash"
      "intremap=on"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ];

    # plymouth, showing after LUKS unlock
    plymouth.enable = true;
    # plymouth.font = "${pkgs.hack-font}/share/fonts/truetype/Hack-Regular.ttf";
    # plymouth.logo = "${pkgs.nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake.png";
  };
}
