{ config, pkgs, ... }:
{
  home.username = "gaugendre";
  home.homeDirectory = "/home/gaugendre";
  home.stateVersion = "25.11";

  programs.fish = {
    enable = true;
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      nil
      nixd
    ];
    settings = {
      theme = "catppuccin_mocha";
      editor = {
        line-number = "relative";
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
  };

  programs.git = {
    enable = true;
    attributes = ["go.sum merge=union"];
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

  services.gpg-agent = {
    enable = true;
    enableFishIntegration = true;
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
    };
  };

  services.ssh-agent = {
    enable = true;
    enableFishIntegration = true;
  };
}
