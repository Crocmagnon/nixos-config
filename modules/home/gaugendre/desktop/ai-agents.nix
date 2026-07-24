{ pkgs, ... }:
{
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
    };
  };
}
