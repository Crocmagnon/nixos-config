{ ... }:
{
  programs.plasma = {
    enable = true;

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
    };
  };

  home.file.".face.icon".source = ./face-icon.jpeg;
}
