{
  config,
  lib,
  pkgs,
  ...
}:
let
  sources = config.catppuccin.sources;
  helixThemeFor = flavor: "${sources.helix}/no_italics/catppuccin_${flavor}.toml";

  # Amorce : si le hook fish n'a jamais tourné (première activation, session sans
  # fish, root), il faut quand même que catppuccin.toml existe, sinon helix ne
  # trouve pas son thème et repart sur celui par défaut.
  defaultAutoTheme = pkgs.writeText "catppuccin-auto.toml" ''
    inherits = "catppuccin-latte"
  '';
in
{
  # Le module amont ne poserait qu'une saveur et nommerait le thème d'après elle.
  catppuccin.helix.enable = false;

  xdg.configFile = {
    "helix/themes/catppuccin-latte.toml".source = helixThemeFor "latte";
    "helix/themes/catppuccin-mocha.toml".source = helixThemeFor "mocha";

    # calme-* : catppuccin réorganisé selon les principes de
    # https://tonsky.me/blog/syntax-highlighting/. Posés mais pas actifs : le
    # hook de theme-auto.nix pointe sur catppuccin-*. Pour les essayer, `:theme
    # calme-latte` dans helix. Ils n'en surchargent que la syntaxe, donc les
    # catppuccin-* ci-dessus doivent rester posés.
    "helix/themes/calme-latte.toml".source = ./helix-themes/calme-latte.toml;
    "helix/themes/calme-mocha.toml".source = ./helix-themes/calme-mocha.toml;
  };

  # catppuccin.toml n'est pas géré par home-manager : c'est le hook fish de
  # theme-auto.nix qui l'écrit. On se contente de l'amorcer s'il manque.
  home.activation.helixCatppuccinSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    themeFile="${config.xdg.configHome}/helix/themes/catppuccin.toml"
    if [ ! -e "$themeFile" ]; then
      $DRY_RUN_CMD install -Dm644 ${defaultAutoTheme} "$themeFile"
    fi
  '';

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      # Nom constant : SIGUSR1 fait relire config.toml à helix et réapplique le
      # thème qui y est nommé, en jetant tout override runtime. C'est donc le
      # fichier catppuccin.toml qui change de `inherits`, pas ce nom.
      theme = "catppuccin";
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
