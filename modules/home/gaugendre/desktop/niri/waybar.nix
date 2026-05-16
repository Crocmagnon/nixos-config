{ lib, pkgs, ... }:
let
  bin = {
    pavucontrol = lib.getExe pkgs.pavucontrol;
    gnomePowerStatistics = "${pkgs.gnome-power-manager}/bin/gnome-power-statistics";
    gnomeCalendar = lib.getExe pkgs.gnome-calendar;
  };
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = false;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 4;
      modules-left = [
        "niri/workspaces"
        "niri/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "pulseaudio"
        "battery"
        "network"
        "tray"
      ];

      "niri/workspaces" = { };
      "niri/window" = {
        format = "{title}";
        max-length = 60;
      };
      clock = {
        format = "{:%H:%M  %a %d %b}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        on-click = bin.gnomeCalendar;
      };
      battery = {
        format = "{icon} {capacity}%";
        format-charging = " {capacity}%";
        format-plugged = " {capacity}%";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
        ];
        states = {
          warning = 20;
          critical = 10;
        };
        on-click = bin.gnomePowerStatistics;
      };
      network = {
        format-wifi = "  {essid} ({signalStrength}%)";
        format-ethernet = "  {ipaddr}";
        format-disconnected = "no net";
        tooltip-format = "{ifname}: {ipaddr}";
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = " muted";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = bin.pavucontrol;
      };
      tray.spacing = 10;
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono", sans-serif;
        font-size: 13px;
        min-height: 0;
      }
      window#waybar {
        background-color: rgba(30, 30, 46, 0.9);
        color: #cdd6f4;
      }
      #workspaces button {
        padding: 0 8px;
        color: #cdd6f4;
        background: transparent;
      }
      #workspaces button.focused {
        background: #585b70;
      }
      #clock,
      #battery,
      #network,
      #pulseaudio,
      #tray,
      #window {
        padding: 0 10px;
      }
      #battery.warning  { color: #f9e2af; }
      #battery.critical { color: #f38ba8; }
    '';
  };
}
