{
  ...
}:
{
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      editor = {
        line-number = "relative";
        bufferline = "multiple";
        cursorline = true;
        color-modes = true;
        # COLORTERM n'est pas transmis par SSH, et le terminfo de xterm-256color
        # n'annonce pas RGB : sur srv-1 la détection de helix échoue, il refuse
        # tout thème Catppuccin en silence et repart sur son thème par défaut.
        true-color = true;
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        indent-guides = {
          render = true;
        };
        inline-diagnostics = {
          cursor-line = "warning";
        };
      };
      keys.normal = {
        Z.Z = ":wq";
      };
    };
    languages = {
      language = [
        {
          name = "nix";
          auto-format = true;
          formatter.command = "nixfmt";
        }
      ];
    };
  };
}
