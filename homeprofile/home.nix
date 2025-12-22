{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.username = "gaugendre";
  home.homeDirectory = "/home/gaugendre";
  home.stateVersion = "25.11";
  home.packages = with pkgs; [
    wl-clipboard
    terraform
    git-crypt
    tlrc
    git-toolbelt
    pre-commit
    watchexec
  ];

  programs.htop.enable = true;
  programs.btop.enable = true;
  programs.tmux.enable = true;

  services.tldr-update = {
    enable = true;
    package = pkgs.tlrc;
  };

  programs.bash.enable = true;

  programs.fish = {
    enable = true;
    interactiveShellInit = (builtins.readFile ./config.fish);
    plugins = with pkgs.fishPlugins; [
      {
        name = "done";
        inherit (done) src;
      }
      {
        name = "autopair";
        inherit (autopair) src;
      }
      {
        name = "fzf";
        inherit (fzf-fish) src;
      }
    ];
    shellAliases = {
      k = "kubectl";
      kctx = "kubectl ctx";
      ping8 = "ping 1.1.1.1";
      static-server = "go run github.com/eliben/static-server@latest";
    };
    functions = {
      ansible-encrypt-to-clipboard = ''
        read -s val
        ansible-vault encrypt_string -- "$val" | grep -v Encryption | pbcopy
      '';
      cat = {
        wraps = "bat";
        body = ''
          if type -q bat
            bat $argv
          else
            command cat $argv
          end
        '';
      };
      pbcopy = ''
        set cmd command pbcopy
        if type -q xclip
          set cmd xclip -sel clipboard
        end
        if type -q wl-copy
          set cmd wl-copy
        end
        $cmd
      '';
      showcert = "openssl s_client -connect $argv[1]:443 -servername $argv[1] -showcerts < /dev/null";
    };
  };

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

  programs.starship = {
    enable = true;
    settings = lib.mkMerge [
      (builtins.fromTOML (
        builtins.readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml"
      ))
      { }
    ];
  };
  programs.fd.enable = true;
  programs.mise.enable = true;
  programs.zoxide.enable = true;
  programs.go = {
    enable = true;
    env.CGO_ENABLED = "0";
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      nil
      nixd
      nixfmt
      gotools
      gopls
      golangci-lint
      delve
      golangci-lint-langserver
      terraform-ls
    ];
    settings = {
      editor = {
        line-number = "relative";
        bufferline = "multiple";
        cursorline = true;
        color-modes = true;
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        indent-guides = {
          render = true;
        };
      };
      keys.normal = {
        Z.Z = ":wq";
      };
    };
    languages = {
      language = [
        {
          name = "go";
          auto-format = true;
          formatter = {
            command = "goimports";
          };
        }
        {
          name = "nix";
          auto-format = true;
          formatter.command = "nixfmt";
        }
      ];
      language-server.gopls.config = {
        "ui.diagnostic.staticcheck" = true;
        "formatting.gofumpt" = true;
      };
    };
  };

  programs.git = {
    enable = true;
    attributes = [ "go.sum merge=union" ];
    ignores = [
      ".local"

      "*.pyc"
      ".tox"
      ".venv"

      # specific
      ".idea"
      ".tool-versions"
      ".envrc"
      ".direnv"
      ".rtx.toml"
      ".mise.toml"
      "mise.local.toml"
      ".vscode"
    ];
    lfs.enable = true;
    settings = {
      user = {
        name = "Gabriel Augendre";
        email = "gabriel@augendre.info";
      };
      color = {
        ui = true;
        status = "auto";
        branch = "auto";
        diff = "auto";
        interactive = "auto";
      };
      push = {
        default = "simple";
        autoSetupRemote = true;
        followtags = true;
      };
      help.autocorrect = "immediate";
      alias = {
        ci = "commit";
        cp = "cherry-pick";
        co = "checkout";
        cob = "switch -c";
        cobf = "! \"f() { git branch -D $1 && git switch -c $1; }; f\"";
        lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
        lola = "lol --all";
        gl = "log --graph --pretty=format:'%C(auto)%h %C(bold blue)<%an>%Creset%C(auto) (%G?) %d %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative";
        wtf = "log --pretty=tformat:\"%C(auto,yellow)%h%C(auto)%d%C(auto,reset) by %C(auto,blue)%cn%C(auto,reset), %C(auto,cyan)%ar%C(auto,reset)%n %s%n\" --stat";
        s = "status -sb";
        pushf = "push --force-with-lease --force-if-includes";
        gone = "! \"git fetch -p && git for-each-ref --format '%(refname:short) %(upstream:track)' | awk '$2 == \"[gone]\" {print $1}' | grep -v master | grep -v develop | xargs -r git branch -D\"";
        tagam = "! \"f() { git tag -a $1 -m \"$1\"; }; f\"";
        pushtag = "push --follow-tags";
        diffs = "diff --staged";
        restores = "restore --staged";
      };
      commit = {
        verbose = true;
        gpgSign = true;
      };
      rerere.enabled = true;
      core = {
        editor = "hx";
        autocrlf = "input";
      };
      submodule.recurse = true;
      fetch = {
        prune = true;
        prunetags = true;
      };
      log.date = "iso";
      status.submoduleSummary = true;
      diff = {
        colorMoved = "default";
        algorithm = "histogram";
        submodule = "log";
      };
      "diff \"color\"".textconv = "pygmentize";
      "diff \"pandoc2md\"".textconv = "pandoc --to=markdown";
      "diff \"pdfconv\"".textconv = "pdftohtml -stdout";
      "diff \"exif\"".textconv = "exiftool";
      "diff \"ziplist\"".textconv = "unzip -l";
      merge = {
        conflictstype = "zdiff3";
      };
      pull.rebase = true;
      rebase = {
        autosquash = true;
        autostash = true;
        updateRefs = true;
      };
      init.defaultBranch = "main";
      branch.sort = "-committerdate";
      advice.detachedHead = false;
      checkout.defaultRemote = "origin";
      tag = {
        sort = "version:refname";
        gpgSign = true;
      };
    };
  };

  programs.gpg = {
    enable = true;
    homedir = "${config.xdg.dataHome}/gnupg";
    settings = {
      use-agent = true;
    };
  };

  services.gpg-agent.enable = true;

  programs.bat.enable = true;

  catppuccin.enable = true;

  home.file."konsole-catppuccin-mocha-theme" = {
    target = ".local/share/konsole/catppuccin-mocha.colorscheme";
    source =
      let
        repo = pkgs.fetchFromGitHub {
          owner = "catppuccin";
          repo = "konsole";
          rev = "3b64040e3f4ae5afb2347e7be8a38bc3cd8c73a8";
          sha256 = "sha256-d5+ygDrNl2qBxZ5Cn4U7d836+ZHz77m6/yxTIANd9BU=";
        };
      in
      "${repo}/themes/catppuccin-mocha.colorscheme";
  };

  home.file."konsole-catppuccin-latte-theme" = {
    target = ".local/share/konsole/catppuccin-latte.colorscheme";
    source =
      let
        repo = pkgs.fetchFromGitHub {
          owner = "catppuccin";
          repo = "konsole";
          rev = "3b64040e3f4ae5afb2347e7be8a38bc3cd8c73a8";
          sha256 = "sha256-d5+ygDrNl2qBxZ5Cn4U7d836+ZHz77m6/yxTIANd9BU=";
        };
      in
      "${repo}/themes/catppuccin-latte.colorscheme";
  };

  home.file."konsole-catppuccin-mocha-profile" = {
    target = ".local/share/konsole/catppuccin-mocha.profile";
    source = ./konsole-catppuccin-mocha.profile;
  };

  home.file."konsole-catppuccin-latte-profile" = {
    target = ".local/share/konsole/catppuccin-latte.profile";
    source = ./konsole-catppuccin-latte.profile;
  };

  home.file."nix-config" = {
    target = ".config/nixpkgs/config.nix";
    source = ./config.nix;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      ubuntu.user = "gaugendre";
      vps-2.user = "ubuntu";
      vps-3.user = "gaugendre";
      "vps-2 vps-3 ubuntu" = {
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
