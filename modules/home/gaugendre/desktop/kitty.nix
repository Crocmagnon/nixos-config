{ pkgs, ... }:
let
  kittyThemes = "${pkgs.kitty-themes}/share/kitty-themes/themes";

  # Corrections propres à Latte : sur fond clair, le thème amont mappe blanc et
  # magenta/cyan sur des teintes de surface presque invisibles. La palette Mocha
  # amont, elle, est saine (surface1 / pink / teal / subtext1, tous lisibles sur
  # base sombre), donc ces huit clés ne concernent que le fichier clair.
  latteTheme = pkgs.runCommand "kitty-catppuccin-latte.conf" { } ''
    cat ${kittyThemes}/Catppuccin-Latte.conf > $out
    cat >> $out <<'EOF'

    # noir -> overlay0 (amont : subtext1/subtext0, trop proches du texte)
    color0  #9CA0B0
    color8  #9CA0B0
    # magenta -> mauve (amont : pink, délavé)
    color5  #8839EF
    color13 #8839EF
    # cyan -> sky (amont : teal, terne)
    color6  #04A5E5
    color14 #04A5E5
    # blanc -> couleur de texte (amont : surface1/surface2, illisibles)
    color7  #4C4F69
    color15 #4C4F69
    EOF
  '';
in
{
  # Le module amont pose un `include` figé dans kitty.conf, qui gagnerait sur la
  # bascule automatique. kitty applique tout seul les fichiers *-theme.auto.conf
  # selon la préférence du portail XDG, à chaud et sans redémarrage.
  catppuccin.kitty.enable = false;

  xdg.configFile = {
    "kitty/dark-theme.auto.conf".source = "${kittyThemes}/Catppuccin-Mocha.conf";
    "kitty/light-theme.auto.conf".source = latteTheme;
    # Terminal qui n'annonce aucune préférence : on retombe sur le clair, qui
    # était la saveur figée jusqu'ici.
    "kitty/no-preference-theme.auto.conf".source = latteTheme;
  };

  programs.kitty = {
    enable = true;

    # Codelia vient d'age/fonts (déchiffrée dans ~/.local/share/fonts), donc pas
    # de package à installer ici.
    font = {
      name = "Codelia";
      size = 12;
    };

    settings = {
      auto_reload_config = "0.1";
      text_composition_strategy = "1.5 0";
      # SGR 2 (faint) mélange le premier plan vers le fond. Le défaut 0.4 laisse
      # le texte dim à 1.9:1 sur le fond Latte, illisible ; 0.8 reste nettement
      # plus pâle que le texte normal tout en passant le contraste.
      dim_opacity = "0.8";
      window_padding_width = 2;
    };
  };

  # Plasma 6 n'expose pas d'option plasma-manager pour ça ; le KCM « Applications
  # par défaut » écrit ces deux clés. TerminalApplication est l'héritage Plasma 5,
  # TerminalService le .desktop que consulte Plasma 6.
  programs.plasma.configFile.kdeglobals.General = {
    TerminalApplication = "kitty";
    TerminalService = "kitty.desktop";
  };
}
