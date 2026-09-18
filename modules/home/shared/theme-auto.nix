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
        # Tant que le terminal n'a pas répondu à OSC 11, la variable est vide.
        # Ne rien faire : en déduire « clair » réécrirait le thème de helix et
        # le ferait clignoter à chaque ouverture de terminal, avant que la vraie
        # valeur n'arrive une fraction de seconde plus tard.
        test -z "$fish_terminal_color_theme"; and return 0

        set -l flavor latte
        if test "$fish_terminal_color_theme" = dark
            set flavor mocha
            set -gx STARSHIP_CONFIG ${starshipMocha}
            set -gx EZA_CONFIG_DIR ${ezaThemeFor "mocha"}
        else
            set -e STARSHIP_CONFIG
            set -e EZA_CONFIG_DIR
        end

        set -l themeFile "${config.xdg.configHome}/helix/themes/catppuccin.toml"
        set -l want "inherits = \"catppuccin-$flavor\""
        # N'écrire et ne signaler que si ça change : sinon chaque nouveau shell
        # enverrait un SIGUSR1 à tous les helix ouverts.
        if test "$(cat $themeFile 2>/dev/null)" != "$want"
            echo $want > $themeFile
            # hx est un wrapper qui exécute .hx-wrapped : le nom vu par pkill est
            # l'un ou l'autre. Deux motifs courts plutôt qu'une alternative, car
            # pkill refuse tout motif de plus de 15 caractères — la taille de
            # comm. -x est indispensable : sans lui le match se ferait par
            # sous-chaîne, et SIGUSR1 tue un processus qui ne le gère pas.
            ${pkgs.procps}/bin/pkill -USR1 -x hx
            ${pkgs.procps}/bin/pkill -USR1 -x '\.hx-wrapped'
        end
        return 0
    end
    __theme_auto
  '';
}
