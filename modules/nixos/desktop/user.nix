{ pkgs, ... }:
{

  users.users.gaugendre = {
    isNormalUser = true;
    description = "Gabriel";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
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

  # passwordless sudo
  security.sudo.extraRules = [
    {
      users = [ "gaugendre" ];
      commands = [
        {
          command = "ALL";
          options = [
            "SETENV"
            "NOPASSWD"
          ];
        }
      ];
    }
  ];

  programs.gnupg.agent = {
    enable = true;
  };

  programs.firefox.enable = true;
  programs.steam.enable = true;

  programs.kdeconnect.enable = true;
}
