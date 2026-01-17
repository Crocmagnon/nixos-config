{
  # After first boot, SSH in and run:
  # btrfs device add -f /dev/sdb2 /
  # btrfs balance start -dconvert=raid1 -mconvert=raid1 /
  #
  # then check with:
  # btrfs filesystem df /
  # expected: Data, System and Metadata "RAID1"
  #
  # check balance status if long:
  # btrfs balance status /
  disko.devices = {
    disk = {
      disk1 = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/" = {
                    mountpoint = "/";
                    mountOptions = [ "noatime" ];
                  };
                };
              };
            };
          };
        };
      };
      disk2 = {
        type = "disk";
        device = "/dev/sdb";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot-fallback";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
              };
            };
          };
        };
      };
    };
  };
}
