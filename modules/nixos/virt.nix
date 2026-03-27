{ pkgs, ... }:
{
  # https://wiki.nixos.org/wiki/Virt-manager
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      vhostUserPackages = with pkgs; [ virtiofsd ];
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;
  users.users.gaugendre.extraGroups = [ "libvirtd" ];
}
