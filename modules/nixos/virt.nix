{ pkgs, ... }:
{
  # https://wiki.nixos.org/wiki/Virt-manager
  virtualisation.libvirtd = {
    enable = true;
    qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
  };
  programs.virt-manager.enable = true;
  users.users.gaugendre.extraGroups = [ "libvirtd" ];
}
