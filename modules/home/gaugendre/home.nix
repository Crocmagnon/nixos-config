{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../shared
    ./git.nix
  ];

  home.username = "gaugendre";
  home.homeDirectory = "/home/gaugendre";
  home.stateVersion = "25.11";
  home.packages = with pkgs; [
    git-crypt
    tlrc # tldr provider
    git-toolbelt
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
  programs.fish.functions.zoxide-scan = {
    description = "Ajoute à zoxide la racine de chaque repo git sous un répertoire";
    body = ''
      set -l root (test -n "$argv[1]" && echo $argv[1] || pwd)
      fd --hidden --no-ignore --type d --max-depth 6 '^\.git$' $root | while read -l gitdir
          zoxide add (path dirname $gitdir)
      end
    '';
  };

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

  catppuccin = import ../../../lib/catppuccin.nix;

  home.file."nix-config" = {
    target = ".config/nixpkgs/config.nix";
    source = ./config.nix;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
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
