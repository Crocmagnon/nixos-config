# Bascule automatique Catppuccin latte/mocha, pilotée par la couleur de fond du
# terminal. Ce module est partagé par gaugendre et root sur toutes les machines :
# c'est ce qui fait que les sessions SSH vers srv-1 suivent aussi, puisque la
# requête OSC 11 traverse sshd comme n'importe quels octets sur le pty.
#
# Voir docs/superpowers/specs/2026-09-18-terminal-theme-auto-switch-design.md
{
  config,
  lib,
  pkgs,
  ...
}:
let
  sources = config.catppuccin.sources;

  fishThemeFor = flavor: "${sources.fish}/static/catppuccin-${flavor}.theme";

  # Les fichiers amont sont plats. fish veut un seul fichier à sections : il y
  # installe alors de lui-même un hook --on-variable fish_terminal_color_theme
  # qui réapplique la bonne variante à chaque changement, dans tous les shells
  # ouverts. [unknown] = terminal qui ne répond pas (pas de tty, lien lent) : on
  # retombe sur le clair, la saveur figée jusqu'ici.
  fishTheme = pkgs.runCommand "catppuccin-auto.theme" { } ''
    {
      echo "# name: 'Catppuccin auto'"
      echo
      echo "[light]"
      cat ${fishThemeFor "latte"}
      echo
      echo "[dark]"
      cat ${fishThemeFor "mocha"}
      echo
      echo "[unknown]"
      cat ${fishThemeFor "latte"}
    } > $out
  '';

  tomlFormat = pkgs.formats.toml { };

  # starship est un process par prompt : changer STARSHIP_CONFIG suffit, l'effet
  # est au prompt suivant. Le ~/.config/starship.toml écrit par le module reste
  # la version claire, donc seule la sombre a besoin d'un fichier dédié.
  starshipMocha = tomlFormat.generate "starship-mocha.toml" (
    config.programs.starship.settings
    // {
      palette = "catppuccin_mocha";
    }
    // lib.importTOML "${sources.starship}/mocha.toml"
  );

  ezaThemeFor =
    flavor:
    pkgs.runCommand "eza-theme-${flavor}" { } ''
      mkdir -p $out
      cp ${sources.eza}/${flavor}/catppuccin-${flavor}-${config.catppuccin.accent}.yml $out/theme.yml
    '';
in
{
  # bat 0.26 sait choisir seul entre un thème clair et un thème sombre en
  # interrogeant le fond du terminal. Le module amont ne poserait qu'une saveur.
  catppuccin.bat.enable = false;

  programs.bat = {
    config = {
      theme = "auto";
      theme-dark = "Catppuccin Mocha";
      theme-light = "Catppuccin Latte";
    };
    themes = {
      "Catppuccin Mocha" = {
        src = sources.bat;
        file = "Catppuccin Mocha.tmTheme";
      };
      "Catppuccin Latte" = {
        src = sources.bat;
        file = "Catppuccin Latte.tmTheme";
      };
    };
  };

  catppuccin.fish.enable = false;
  catppuccin.starship.enable = false;
  catppuccin.eza.enable = false;

  xdg.configFile."fish/themes/catppuccin.theme".source = fishTheme;

  # Saveur claire par défaut, aux emplacements standards : c'est ce que voient
  # bash, root et tout shell où le hook n'a pas tourné.
  programs.starship.settings = {
    palette = "catppuccin_latte";
  }
  // lib.importTOML "${sources.starship}/latte.toml";

  xdg.configFile."eza/theme.yml".source = "${ezaThemeFor "latte"}/theme.yml";

  # mkAfter : doit passer après l'init de fish lui-même.
  programs.fish.interactiveShellInit = lib.mkAfter ''
    fish_config theme choose catppuccin

    # starship, eza et helix n'ont aucune détection propre. fish, lui, pose
    # fish_terminal_color_theme dès que le terminal a répondu à OSC 11 : on s'y
    # accroche. L'appel explicite en fin de bloc couvre le cas où la variable est
    # déjà posée au moment où la fonction est définie.
    function __theme_auto --on-variable fish_terminal_color_theme
        if test "$fish_terminal_color_theme" = dark
            set -gx STARSHIP_CONFIG ${starshipMocha}
            set -gx EZA_CONFIG_DIR ${ezaThemeFor "mocha"}
        else
            set -e STARSHIP_CONFIG
            set -e EZA_CONFIG_DIR
        end

        set -l flavor latte
        test "$fish_terminal_color_theme" = dark; and set flavor mocha
        set -l themeFile "${config.xdg.configHome}/helix/themes/catppuccin.toml"
        set -l want "inherits = \"catppuccin-$flavor\""
        # N'écrire et ne signaler que si ça change : sinon chaque nouveau shell
        # enverrait un SIGUSR1 à tous les helix ouverts.
        if test "$(cat $themeFile 2>/dev/null)" != "$want"
            echo $want > $themeFile
            # Motif exact : hx est un wrapper qui exécute .hx-wrapped, donc le
            # nom vu par pkill est l'un ou l'autre. Sans -x le motif matcherait
            # par sous-chaîne, et l'action par défaut de SIGUSR1 étant de tuer
            # le processus, un faux positif serait destructeur.
            ${pkgs.procps}/bin/pkill -USR1 -x '\.?hx(-wrapped)?'
        end
        return 0
    end
    __theme_auto
  '';
}
