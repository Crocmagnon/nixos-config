{ ... }:
{
  boot = {
    supportedFilesystems = [ "btrfs" ];

    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";

        mirroredBoots = [
          {
            devices = [ "nodev" ];
            path = "/boot";
            efiSysMountPoint = "/boot";
          }
          {
            devices = [ "nodev" ];
            path = "/boot-fallback";
            efiSysMountPoint = "/boot-fallback";
          }
        ];
      };

      # efi.canTouchEfiVariables = true;
    };
  };
}
