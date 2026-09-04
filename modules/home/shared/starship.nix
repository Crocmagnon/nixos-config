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
      (builtins.fromTOML (builtins.readFile "${pkgs.starship}/share/starship/presets/no-nerd-font.toml"))
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
          format = "[⏱ $duration]($style) ";
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
          # $symbol retiré : c'est un glyphe Nerd Font (U+E0A0) que le préréglage
          # no-nerd-font ne remplace pas. only_attached évite un « HEAD » redondant
          # avec la ligne git_commit quand on est sur un tag.
          format = "[$branch(:$remote_branch)]($style) ";
          only_attached = true;
          style = "green";
        };

        # Sans tag_disabled = false, un HEAD détaché n'affiche que le hash.
        git_commit = {
          tag_disabled = false;
          tag_symbol = " #";
        };
        git_status = {
          format = "[$ahead_behind$all_status]($style)";
          # style est la couleur par défaut du bloc ; les styles imbriqués des
          # sous-champs l'écrasent. L'espace reste hors des crochets.
          style = "yellow";
          conflicted = "=$count ";
          ahead = "[⇡$count](green) ";
          behind = "[⇣$count](green) ";
          diverged = "[⇡$ahead_count ⇣$behind_count](green) ";
          untracked = "[?$count](blue) ";
          stashed = "[*$count](green) ";
          modified = "!$count ";
          staged = "+$count ";
          renamed = "»$count ";
          deleted = "✘$count ";
        };
      }
    ];
  };
}
