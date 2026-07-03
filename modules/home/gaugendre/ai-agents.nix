{ pkgs, ... }:
{
  # rtk (Rust Token Killer) : proxy CLI qui compresse la sortie des commandes de dev
  # pour réduire la consommation de tokens. Doit être sur le PATH pour que les
  # commandes réécrites par le hook (`git status` -> `rtk git status`) s'exécutent.
  home.packages = [ pkgs.rtk ];

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    settings = {
      theme = "auto";
      tui = "fullscreen";
      language = "french";
      permissions = {
        defaultMode = "plan";
        allow = [
          "Bash(git status:*)"
          "Bash(git diff:*)"
          "Bash(git log:*)"
          "Bash(git branch:*)"
          "Bash(git show:*)"
          "Bash(nix flake check:*)"
          "Bash(nix build:*)"
          "Bash(nix eval:*)"
          "Bash(nixos-rebuild dry-build:*)"
          "Bash(nixos-rebuild dry-activate:*)"
        ];
        deny = [
          "Bash(curl:*)"
          "Bash(wget:*)"
        ];
      };
      extraKnownMarketplaces.ponytail.source = {
        source = "github";
        repo = "DietrichGebert/ponytail";
      };
      enabledPlugins."ponytail@ponytail" = true;
      enabledPlugins."superpowers@claude-plugins-official" = true;
      # Hook rtk : réécrit les commandes Bash pour les passer par rtk (token savings).
      hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "${pkgs.rtk}/bin/rtk hook claude";
            }
          ];
        }
      ];
    };
  };
}
