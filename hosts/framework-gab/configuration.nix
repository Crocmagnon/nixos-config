{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/locale.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/audio.nix
    ./home
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.bluetooth.enable = true;

  catppuccin.enable = true;
  catppuccin.sddm.enable = false;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "framework-gab";
  networking.networkmanager.enable = true;

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # https://github.com/NixOS/nixpkgs/issues/239770
  security.pam.services.login.fprintAuth = false;

  services.printing.enable = true;

  # Sound needs to be enabled for some apps to work

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
    ];
  };

  programs.gnupg.agent = {
    enable = true;
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

  programs.firefox.enable = true;
  programs.steam.enable = true;

  environment.systemPackages = with pkgs; [
    bind # dig, among other
  ];

  services.fprintd = {
    enable = true;
    #  tod.enable = true;
    #  tod.driver = pkgs.libfprint-2-tod1-goodix;
  };

  # Fix fprintd recognizing fingerprint after suspend
  powerManagement.powerDownCommands = ''
    ${pkgs.systemd}/bin/systemctl stop fprintd.service 2>/dev/null || true
  '';

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  programs.kdeconnect.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
