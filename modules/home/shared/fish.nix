{
  pkgs,
  ...
}:
{
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
      ping8 = "ping 1.1.1.1";
    };
    functions = {
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
      _here = "$argv[1] . > /dev/null 2>&1 &; disown";
      pycharm-here = "_here pycharm";
    };
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = false; # disable because conflicts with fzf.fish which is nicer
  };
}
