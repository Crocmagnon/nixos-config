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
      language-server = {
        gopls.config = {
          "ui.diagnostic.staticcheck" = true;
          "formatting.gofumpt" = true;
        };
        rust-analyzer.config = {
          check.command = "clippy";
          # cargo.features = "all";
        };
      };
    };
  };
}
