{
  config,
  lib,
  pkgs,
  ...
}:
let
  bin = {
    waybar = lib.getExe pkgs.waybar;
    mako = lib.getExe pkgs.mako;
    swaybg = lib.getExe pkgs.swaybg;
    hyprlock = lib.getExe pkgs.hyprlock;
    swayidle = lib.getExe pkgs.swayidle;
    fuzzel = lib.getExe pkgs.fuzzel;
    konsole = lib.getExe pkgs.kdePackages.konsole;
    polkitKdeAgent = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
    kwalletd = "${pkgs.kdePackages.kwallet}/bin/kwalletd6";
    nmApplet = "${pkgs.networkmanagerapplet}/bin/nm-applet";
    wpctl = "${pkgs.wireplumber}/bin/wpctl";
    brightnessctl = lib.getExe pkgs.brightnessctl;
    niri = lib.getExe config.programs.niri.package;
  };
in
{
  programs.niri.settings = {
    input = {
      keyboard.xkb = {
        layout = "fr";
      };
      touchpad = {
        tap = true;
        natural-scroll = true;
        dwt = true;
      };
    };

    layout = {
      gaps = 8;
      center-focused-column = "never";
      preset-column-widths = [
        { proportion = 1.0 / 3.0; }
        { proportion = 0.5; }
        { proportion = 2.0 / 3.0; }
      ];
      default-column-width.proportion = 0.5;
    };

    xwayland-satellite = {
      enable = true;
      path = lib.getExe pkgs.xwayland-satellite;
    };

    spawn-at-startup = [
      { command = [ bin.waybar ]; }
      { command = [ bin.mako ]; }
      {
        command = [
          bin.swaybg
          "-c"
          "#1e1e2e"
        ];
      }
      { command = [ bin.polkitKdeAgent ]; }
      { command = [ bin.kwalletd ]; }
      {
        command = [
          bin.nmApplet
          "--indicator"
        ];
      }
      {
        command = [
          bin.swayidle
          "-w"
          "timeout"
          "600"
          bin.hyprlock
          "timeout"
          "900"
          "${bin.niri} msg action power-off-monitors"
          "before-sleep"
          bin.hyprlock
        ];
      }
    ];

    binds = with config.lib.niri.actions; {
      "Mod+Return".action = spawn bin.konsole;
      "Mod+D".action = spawn bin.fuzzel;
      "Mod+Q".action = close-window;
      "Mod+Shift+E".action = quit;
      "Mod+Escape".action = show-hotkey-overlay;
      "Super+Alt+L".action = spawn bin.hyprlock;

      "Mod+H".action = focus-column-left;
      "Mod+L".action = focus-column-right;
      "Mod+J".action = focus-window-down;
      "Mod+K".action = focus-window-up;

      "Mod+Shift+H".action = move-column-left;
      "Mod+Shift+L".action = move-column-right;
      "Mod+Shift+J".action = move-window-down;
      "Mod+Shift+K".action = move-window-up;

      "Mod+R".action = switch-preset-column-width;
      "Mod+F".action = maximize-column;
      "Mod+Shift+F".action = fullscreen-window;
      "Mod+C".action = center-column;

      "Mod+U".action = focus-workspace-down;
      "Mod+I".action = focus-workspace-up;
      "Mod+Shift+U".action = move-column-to-workspace-down;
      "Mod+Shift+I".action = move-column-to-workspace-up;

      "Mod+1".action = focus-workspace 1;
      "Mod+2".action = focus-workspace 2;
      "Mod+3".action = focus-workspace 3;
      "Mod+4".action = focus-workspace 4;
      "Mod+5".action = focus-workspace 5;

      "XF86AudioRaiseVolume".action = spawn bin.wpctl "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
      "XF86AudioLowerVolume".action = spawn bin.wpctl "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";
      "XF86AudioMute".action = spawn bin.wpctl "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
      "XF86MonBrightnessUp".action = spawn bin.brightnessctl "set" "5%+";
      "XF86MonBrightnessDown".action = spawn bin.brightnessctl "set" "5%-";
    };
  };
}
