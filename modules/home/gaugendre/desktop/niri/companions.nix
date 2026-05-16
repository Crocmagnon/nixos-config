{ ... }:
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "konsole";
        layer = "overlay";
        font = "JetBrainsMono Nerd Font:size=12";
      };
      colors = {
        background = "1e1e2eee";
        text = "cdd6f4ff";
        match = "f38ba8ff";
        selection = "585b70ff";
        selection-text = "cdd6f4ff";
        border = "89b4faff";
      };
      border = {
        radius = 8;
        width = 2;
      };
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        grace = 0;
        hide_cursor = false;
      };
      background = [
        {
          monitor = "";
          color = "rgba(30, 30, 46, 1.0)";
        }
      ];
      input-field = [
        {
          monitor = "";
          size = "300, 50";
          outline_thickness = 2;
          outer_color = "rgb(89b4fa)";
          inner_color = "rgb(1e1e2e)";
          font_color = "rgb(cdd6f4)";
          check_color = "rgb(f9e2af)";
          fail_color = "rgb(f38ba8)";
          placeholder_text = "<i>Password</i>";
          position = "0, -80";
          halign = "center";
          valign = "center";
        }
      ];
      label = [
        {
          monitor = "";
          text = "cmd[update:1000] date '+%H:%M'";
          font_size = 80;
          color = "rgb(cdd6f4)";
          position = "0, 200";
          halign = "center";
          valign = "center";
        }
      ];
      auth = {
        fingerprint = {
          enabled = true;
          ready_message = "Scan fingerprint to unlock";
          present_message = "Scanning...";
          retry_delay = 250;
        };
        pam.enabled = true;
      };
    };
  };

  xdg.configFile."mako/config".text = ''
    background-color=#1e1e2e
    text-color=#cdd6f4
    border-color=#89b4fa
    border-size=2
    border-radius=8
    font=JetBrainsMono Nerd Font 11
    default-timeout=5000
  '';
}
