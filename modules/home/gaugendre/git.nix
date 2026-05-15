{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.git = {
    enable = true;
    attributes = [ "go.sum merge=union" ];
    ignores = [
      ".local"

      "*.pyc"
      ".tox"
      ".venv"

      ".idea"
      ".tool-versions"
      ".direnv"
      ".rtx.toml"
      ".mise.toml"
      "mise.local.toml"
      ".vscode"
      ".claude/settings.local.json"
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
        cobf = ''! f() { git branch -D $1 && git switch -c $1; }; f'';
        lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
        lola = "lol --all";
        gl = "log --graph --pretty=format:'%C(auto)%h %C(bold blue)<%an>%Creset%C(auto) (%G?) %d %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative";
        wtf = "log --pretty=tformat:\"%C(auto,yellow)%h%C(auto)%d%C(auto,reset) by %C(auto,blue)%cn%C(auto,reset), %C(auto,cyan)%ar%C(auto,reset)%n %s%n\" --stat";
        s = "status -sb";
        pushf = "push --force-with-lease --force-if-includes";
        gone = ''! git fetch -p && git for-each-ref --format '%(refname:short) %(upstream:track)' | awk '$2 == "[gone]" {print $1}' | grep -v master | grep -v develop | xargs -r git branch -D'';
        tagam = ''! f() { git tag -a $1 -m "$1"; }; f'';
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
}
