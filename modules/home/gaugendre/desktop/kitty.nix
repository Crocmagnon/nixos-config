{ ... }:
{
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

    # Corrections propres à Latte : sur fond clair, le thème amont mappe blanc et
    # magenta/cyan sur des teintes de surface presque invisibles. extraConfig
    # passe après le `include` posé par le module catppuccin, donc ces huit clés
    # gagnent et le reste du thème vient d'amont. À revoir si on repasse en Mocha.
    extraConfig = ''
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
    '';
  };

  # Plasma 6 n'expose pas d'option plasma-manager pour ça ; le KCM « Applications
  # par défaut » écrit ces deux clés. TerminalApplication est l'héritage Plasma 5,
  # TerminalService le .desktop que consulte Plasma 6.
  programs.plasma.configFile.kdeglobals.General = {
    TerminalApplication = "kitty";
    TerminalService = "kitty.desktop";
  };
}
