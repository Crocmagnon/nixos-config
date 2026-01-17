{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./git.nix
    ./fish.nix
    ./starship.nix
    ./helix.nix
    ./konsole
  ];

  home.username = "gaugendre";
  home.homeDirectory = "/home/gaugendre";
  home.stateVersion = "25.11";
  home.packages = with pkgs; [
    wl-clipboard
    git-crypt
    tlrc # tldr provider
    git-toolbelt
    pre-commit
    watchexec # used by mise watch
    amber # like find | sed but easier (ambr before after)
  ];

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

  programs.eza = {
    enable = true;
    git = true;
    icons = "auto";
    extraOptions = [
      "--header"
      "--group"
    ];
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = false; # disable because conflicts with fzf.fish
  };

  programs.fd.enable = true;
  programs.mise.enable = true;
  programs.zoxide.enable = true;
  programs.go = {
    enable = true;
    env.CGO_ENABLED = "0";
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

  programs.bat.enable = true;

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
        user = "hassio";
        port = 32690;
      };
      "*" = {
        addKeysToAgent = "yes";
      };
    };
  };

  services.ssh-agent.enable = true;
}
