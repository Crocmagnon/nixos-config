{
  config,
  pkgs,
  lib,
  ...
}:
let
  identity = import ../../../lib/identity.nix;
in
{
  programs.git = {
    enable = true;
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
        name = identity.fullName;
        email = identity.email;
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
        sw = "switch";
        cob = "switch -c";
        cobf = "! f() { git branch -D $1 && git switch -c $1; }; f";
        lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
        lola = "lol --all";
        gl = "log --graph --pretty=format:'%C(auto)%h %C(bold blue)<%an>%Creset%C(auto) (%G?) %d %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative";
        wtf = "log --pretty=tformat:\"%C(auto,yellow)%h%C(auto)%d%C(auto,reset) by %C(auto,blue)%cn%C(auto,reset), %C(auto,cyan)%ar%C(auto,reset)%n %s%n\" --stat";
        s = "status -sb";
        stat = "diff --shortstat";
        statmain = "stat main...HEAD";
        praise = "blame";
        balance = "blame";
        syn = "! git pull --rebase && git push";
        ign = ''! curl -L -s "https://www.gitignore.io/api/$@"'';
        # Se déplacer le long de la branche courante : prev recule d'un commit,
        # next avance vers main, first saute au commit initial.
        prev = "checkout HEAD^";
        next = "! git checkout $(git rev-list HEAD..\${1:-main} --ancestry-path | tail -1 || echo HEAD)";
        first = "! git checkout $(git rev-list --max-parents=0 HEAD)";
        pushf = "push --force-with-lease --force-if-includes";
        gone = ''! git fetch -p && git for-each-ref --format '%(refname:short) %(upstream:track)' | awk '$2 == "[gone]" {print $1}' | grep -v master | grep -v develop | xargs -r git branch -D'';
        tagam = ''! f() { git tag -a $1 -m "$1"; }; f'';
        rmtag = "! f() { git tag --delete $1; git push --delete origin $1; }; f";
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
        conflictStyle = "zdiff3";
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
      url."git@github.com:".insteadOf = [
        "https://github.com/"
        "gh:"
      ];
    };
  };
}
