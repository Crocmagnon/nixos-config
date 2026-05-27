{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../shared
    ./ai-agents.nix
    ./git.nix
  ];

  home.username = "gaugendre";
  home.homeDirectory = "/home/gaugendre";
  home.stateVersion = "25.11";
  home.packages = with pkgs; [
    git-crypt
    tlrc # tldr provider
    git-toolbelt
    pre-commit
    prek
    nil
    nixd
    nixfmt
    watchexec # used by mise watch
    amber # like find | sed but easier (ambr before after)
    terraform-ls
    vscode-json-languageserver
    yaml-language-server
  ];

  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    # fix man output with bat (remove color codes)
    GROFF_NO_SGR = "1";
  };

  programs.htop.enable = true;
  programs.btop.enable = true;
  programs.tmux.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = true;
  };

  services.tldr-update = {
    enable = true;
    package = pkgs.tlrc;
  };

  programs.bash.enable = true;

  programs.fd.enable = true;
  programs.mise.enable = true;
  programs.zoxide.enable = true;

  programs.uv = {
    enable = true;
    package = pkgs.uv;
  };

  programs.gpg = {
    enable = true;
    homedir = "${config.xdg.dataHome}/gnupg";
    settings = {
      use-agent = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 86400;
    maxCacheTtl = 86400 * 7;
  };

  catppuccin.enable = true;

  home.file."nix-config" = {
    target = ".config/nixpkgs/config.nix";
    source = ./config.nix;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "ubuntu srv-1" = {
        user = "gaugendre";
        forwardAgent = true;
        controlMaster = "auto";
        controlPath = "~/.ssh/control-%C";
        controlPersist = "4h";
      };
      hass = {
        hostname = "192.168.0.9";
        user = "root";
        port = 32690;
      };
      "*" = {
        addKeysToAgent = "yes";
      };
    };
  };

  services.ssh-agent.enable = true;
}
