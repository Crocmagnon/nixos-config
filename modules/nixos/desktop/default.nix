{ pkgs, ... }:
{
  imports = [
    ./locale.nix
    ./fonts.nix
    ./audio.nix
    ./iphone.nix
    ./boot.nix
    ./docker.nix
    ./plasma.nix
    ./home-manager.nix
    ./users.nix
    ./vpn.nix
    ./uv-python.nix
  ];

  catppuccin.enable = true;

  networking.networkmanager.enable = true;

  services.printing.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.partitionmanager
    gokrazy
    bind # dig, among other
    wl-clipboard
  ];

  services.fwupd.enable = true;
}
