{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gotools
    gopls
    golangci-lint
    golangci-lint-langserver
    delve
    jetbrains.goland
  ];
  home.sessionPath = [
    "$HOME/go/bin"
  ];
  programs.fish = {
    shellAliases = {
      static-server = "go run github.com/eliben/static-server@latest";
      goland-here = "_here goland";
    };
  };
  programs.git = {
    attributes = [ "go.sum merge=union" ];
  };
  programs.go = {
    enable = true;
    telemetry.mode = "on";
    env.CGO_ENABLED = "0";
  };
  programs.helix.languages = {
    language = [
      {
        name = "go";
        auto-format = true;
        formatter = {
          command = "goimports";
        };
      }
    ];
    language-server = {
      gopls.config = {
        "ui.diagnostic.staticcheck" = true;
        "formatting.gofumpt" = true;
      };
    };
  };
}
