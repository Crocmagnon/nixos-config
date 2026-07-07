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
    ./nrfconnect.nix
  ];

  catppuccin = {
    enable = true;
    cache.enable = true;
  };

  networking.networkmanager.enable = true;

  services.printing.enable = true;
  services.fwupd.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.partitionmanager
    gokrazy
    bind # dig, among other
    wl-clipboard
    kdePackages.kate
    kdePackages.dolphin-plugins
    prusa-slicer
    libreoffice-qt-still
    # using rustdesk-flutter instead of rustdesk because rustdesk requires a full rebuild from source
    # https://discourse.nixos.org/t/poor-install-performance-for-rustdesk-on-nixos/48829/4
    rustdesk-flutter
    pcloud
    signal-desktop
    openscad-unstable
    freecad
    solvespace
    jetbrains.pycharm
    esphome
    chromium
    jq
    gcc
    koreader
    terraform
  ];

  programs.firefox.enable = true;
  programs.steam.enable = true;
  programs.kdeconnect.enable = true;
}
