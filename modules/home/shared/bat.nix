{ ... }:
{
  programs.bat.enable = true;

  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    # fix man output with bat (remove color codes)
    GROFF_NO_SGR = "1";
  };

  programs.fish = {
    functions = {
      cat = {
        wraps = "bat";
        body = ''
          bat $argv
        '';
      };
    };
  };
}
