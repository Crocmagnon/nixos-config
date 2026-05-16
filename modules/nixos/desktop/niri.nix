{ inputs, pkgs, ... }:
{
  imports = [ inputs.niri.nixosModules.niri ];

  programs.niri.enable = true;
  programs.hyprlock.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.polkit-kde-agent-1
    kdePackages.kwallet
    networkmanagerapplet
    xwayland-satellite
    swaybg
    mako
    swayidle
    grim
    slurp
    brightnessctl
    pavucontrol
    gnome-power-manager
    gnome-calendar
  ];

  security.pam.services.sddm.kwallet = {
    enable = true;
    package = pkgs.kdePackages.kwallet-pam;
  };
}
