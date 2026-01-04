{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.starship = {
    enable = true;
    settings = lib.mkMerge [
      (builtins.fromTOML (
        builtins.readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml"
      ))
      {
        format = "$all$fill$cmd_duration$time$line_break$character";
        fill.symbol = " ";
        time = {
          disabled = false;
          style = "black";
          format = "[$time]($style) ";
        };
        cmd_duration = {
          min_time = 5000;
          style = "black";
          format = "[ $duration]($style) ";
        };
        hostname = {
          format = "[@$hostname]($style) ";
          style = "dimmed yellow";
        };
        username = {
          format = "[$user]($style)";
          style_user = "dimmed yellow";
        };
        directory = {
          fish_style_pwd_dir_length = 1;
          before_repo_root_style = "cyan";
          repo_root_style = "bold cyan";
        };
        git_branch = {
          format = "[$symbol$branch(:$remote_branch)]($style) ";
          style = "green";
        };
        git_status = {
          format = "[$all_status$ahead_behind]($style)";
          style = "yellow";
          conflicted = "=$count ";
          ahead = "⇡$count ";
          behind = "⇣$count ";
          diverged = "⇡$ahead_count ⇣$behind_count ";
          untracked = "?$count ";
          stashed = "\$$count ";
          modified = "!$count ";
          staged = "+$count ";
          renamed = "»$count ";
          deleted = "✘$count ";
        };
      }
    ];
  };
}