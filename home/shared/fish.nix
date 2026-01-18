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

  programs.fzf = {
    enable = true;
    enableFishIntegration = false; # disable because conflicts with fzf.fish which is nicer
  };

  programs.bat.enable = true; # Required for MANPAGER in config.fish
}
