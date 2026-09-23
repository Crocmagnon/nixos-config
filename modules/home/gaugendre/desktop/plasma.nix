{ ... }:
{
  programs.plasma = {
    enable = true;

    # Meta alone kept opening the launcher by accident. Alt+F1 still does it.
    shortcuts.plasmashell."activate application launcher" = "Alt+F1";

    shortcuts.kwin = {
      "Walk Through Windows" = "Meta+Tab";
      "Walk Through Windows (Reverse)" = "Meta+Shift+Tab";
      "Walk Through Windows of Current Application Alternative" = "Alt+Tab";
      "Walk Through Windows of Current Application Alternative (Reverse)" = "Alt+Shift+Tab";
    };

    configFile = {
      kdeglobals.KDE.AutomaticLookAndFeel = true;
      kdeglobals.KDE.AutomaticLookAndFeelOnIdle = false;

      kwinrc.TabBox = {
        ApplicationsMode = 1;
        HighlightWindows = false;
        LayoutName = "big_icons";
      };

      # Baloo indexait le montage FUSE pCloud (1,6 To) : pour indexer le contenu il
      # télécharge chaque fichier, et baloo_file_extractor finit bloqué en D sur une
      # lecture FUSE. Une tâche en D ne peut pas être gelée, donc le noyau annule la
      # mise en veille (« N tasks refusing to freeze ») -- capot fermé, la machine
      # restait allumée. La clé est celle qu'écrit `balooctl6 config add excludeFolders`.
      baloofilerc.General."exclude folders[$e]" = "$HOME/pCloudDrive/";
    };
  };

  home.file.".face.icon".source = ./face-icon.jpeg;
}
