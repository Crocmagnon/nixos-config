{ pkgs, ... }:
{
  users.users.gaugendre = {
  extraGroups = [
      "networkmanager"];
    packages = with pkgs; [
      kdePackages.kate
      prusa-slicer
      libreoffice-qt-still
      # using rustdesk-flutter instead of rustdesk because rustdesk requires a full rebuild from source
      # https://discourse.nixos.org/t/poor-install-performance-for-rustdesk-on-nixos/48829/4
      rustdesk-flutter
      pcloud
      bottles
      signal-desktop
      openscad-unstable
      freecad
      solvespace
      jetbrains.pycharm
      jetbrains.goland
    ];
  };

  programs.firefox.enable = true;
  programs.steam.enable = true;

  programs.kdeconnect.enable = true;
}
