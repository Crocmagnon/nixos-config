# Bascule automatique Catppuccin latte/mocha — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire suivre au setup terminal complet — kitty, herdr, fish, starship, helix, bat, eza, claude — le thème clair/sombre du système, y compris dans les sessions SSH vers srv-1.

**Architecture:** La couleur de fond du terminal est l'unique source de vérité. kitty lit le portail XDG et applique `~/.config/kitty/*-theme.auto.conf` ; herdr relaie l'OSC 11 aux panes ; fish, bat et claude suivent nativement ; un hook fish `--on-variable fish_terminal_color_theme` pilote starship, eza et helix. Toute la logique partagée vit dans `modules/home/shared/`, ce qui la fait exister aussi sur srv-1 et pour `root`.

**Tech Stack:** Nix, NixOS, home-manager, catppuccin/nix (release-26.05), fish 4.7, kitty 0.48, helix 25.07.1, bat 0.26, herdr 0.9, claude-code 2.1.

**Spec:** `docs/superpowers/specs/2026-09-18-terminal-theme-auto-switch-design.md`

## Global Constraints

- Saveur claire : `latte`. Saveur sombre : `mocha`. Accent : `mauve`.
- Repli quand le terminal ne répond pas (`fish_terminal_color_theme` vaut `unknown` ou est vide) : **latte**, qui est le comportement actuel.
- `lib/catppuccin.nix` reste inchangé (`flavor = "latte"`) : c'est la saveur de repli de tout le non-terminal.
- Chaque module amont remplacé doit être explicitement désactivé : `catppuccin.<nom>.enable = false`.
- Les commentaires de code sont en français, comme le reste du dépôt.
- Ne jamais ajouter de trailer `Co-Authored-By` aux commits.
- Branche de travail : `theme-auto-switch` (déjà créée, contient déjà le commit de la spec).
- Chemins des sources catppuccin, tels que le module les expose via `config.catppuccin.sources` :
  - fish : `${sources.fish}/static/catppuccin-<flavor>.theme`
  - starship : `${sources.starship}/<flavor>.toml` (contient `[palettes.catppuccin_<flavor>]`, sans clé `palette` de premier niveau)
  - bat : `${sources.bat}/Catppuccin <Flavor>.tmTheme`
  - eza : `${sources.eza}/<flavor>/catppuccin-<flavor>-mauve.yml`
  - helix : `${sources.helix}/no_italics/catppuccin_<flavor>.toml`
  - kitty : `${pkgs.kitty-themes}/share/kitty-themes/themes/Catppuccin-<Flavor>.conf`

## Structure des fichiers

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `modules/home/shared/helix.nix` *(modifié)* | forçage truecolor, nom de thème indirect, installation des deux saveurs, amorçage du fichier `catppuccin.toml` | 1, 5 |
| `modules/home/gaugendre/desktop/kitty.nix` *(modifié)* | les trois `*.auto.conf`, corrections Latte isolées | 2 |
| `modules/home/gaugendre/desktop/ai-agents.nix` *(modifié)* | herdr `auto_switch`, claude `theme = "auto"` | 3 |
| `modules/home/shared/theme-auto.nix` *(créé)* | bat auto, thème fish fusionné, configs starship/eza doubles, le hook fish | 3, 4, 5 |
| `modules/home/shared/default.nix` *(modifié)* | import du nouveau module | 3 |
| `CLAUDE.md` *(modifié)* | la section catppuccin ne décrit plus la réalité | 6 |

## Vérification

Ce dépôt n'a pas de tests unitaires : le cycle de vérification est l'évaluation Nix et l'inspection des fichiers générés. Deux commandes reviennent partout.

**Évaluation complète des trois machines** — c'est le garde-fou qui attrape les erreurs de syntaxe, les options inexistantes et les régressions sur srv-1 :

```bash
nixos-rebuild dry-build --flake .#framework-gab
nixos-rebuild dry-build --flake .#desktop-gab
nixos-rebuild dry-build --flake .#srv-1
```

**Inspection d'un fichier généré**, sans rebuild complet :

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.framework-gab.config.home-manager.users.gaugendre.xdg.configFile."<chemin>".source'
```

---

### Task 1 : correctif helix true-color

Indépendant du reste : répare un bug préexistant et silencieux. Sur srv-1, `COLORTERM` n'est pas transmis par SSH et le terminfo de `xterm-256color` n'annonce pas RGB, donc helix refuse tout thème Catppuccin et repart sur son thème par défaut sans rien dire.

**Files:**
- Modify: `modules/home/shared/helix.nix`

**Interfaces:**
- Consumes: rien.
- Produces: rien que les tâches suivantes consomment. Le réglage est autonome.

- [ ] **Step 1 : constater le bug**

```bash
ssh srv-1 'env | grep -c "^COLORTERM=" || true'
```

Attendu : `0`. C'est la cause : la variable n'arrive pas.

- [ ] **Step 2 : ajouter le forçage**

Dans `modules/home/shared/helix.nix`, à l'intérieur de `settings.editor`, juste après `color-modes = true;` :

```nix
        # COLORTERM n'est pas transmis par SSH, et le terminfo de xterm-256color
        # n'annonce pas RGB : sur srv-1 la detection de helix echoue, il refuse
        # tout theme Catppuccin en silence et repart sur son theme par defaut.
        true-color = true;
```

- [ ] **Step 3 : vérifier que ça évalue partout**

```bash
nixos-rebuild dry-build --flake .#framework-gab
nixos-rebuild dry-build --flake .#srv-1
```

Attendu : les deux terminent sans erreur.

- [ ] **Step 4 : vérifier le contenu généré**

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.srv-1.config.home-manager.users.gaugendre.xdg.configFile."helix/config.toml".source' \
  | xargs grep -n "true-color"
```

Attendu : une ligne `true-color = true`.

- [ ] **Step 5 : commit**

```bash
git add modules/home/shared/helix.nix
git commit -m "helix: forcer true-color, sinon Catppuccin est refuse en silence sur srv-1"
```

---

### Task 2 : kitty bascule seul

**Files:**
- Modify: `modules/home/gaugendre/desktop/kitty.nix`

**Interfaces:**
- Consumes: rien.
- Produces: la bascule de la palette du terminal, dont tout le reste dépend à l'exécution. Aucune interface Nix.

- [ ] **Step 1 : remplacer le contenu de `modules/home/gaugendre/desktop/kitty.nix`**

```nix
{ pkgs, ... }:
let
  kittyThemes = "${pkgs.kitty-themes}/share/kitty-themes/themes";

  # Corrections propres a Latte : sur fond clair, le theme amont mappe blanc et
  # magenta/cyan sur des teintes de surface presque invisibles. La palette Mocha
  # amont, elle, est saine (surface1 / pink / teal / subtext1, tous lisibles sur
  # base sombre), donc ces huit cles ne concernent que le fichier clair.
  latteTheme = pkgs.runCommand "kitty-catppuccin-latte.conf" { } ''
    cat ${kittyThemes}/Catppuccin-Latte.conf > $out
    cat >> $out <<'EOF'

    # noir -> overlay0 (amont : subtext1/subtext0, trop proches du texte)
    color0  #9CA0B0
    color8  #9CA0B0
    # magenta -> mauve (amont : pink, delave)
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
  # Le module amont pose un `include` fige dans kitty.conf, qui gagnerait sur la
  # bascule automatique. kitty applique tout seul les fichiers *-theme.auto.conf
  # selon la preference du portail XDG, a chaud et sans redemarrage.
  catppuccin.kitty.enable = false;

  xdg.configFile = {
    "kitty/dark-theme.auto.conf".source = "${kittyThemes}/Catppuccin-Mocha.conf";
    "kitty/light-theme.auto.conf".source = latteTheme;
    # Terminal qui n'annonce aucune preference : on retombe sur le clair, qui
    # etait la saveur figee jusqu'ici.
    "kitty/no-preference-theme.auto.conf".source = latteTheme;
  };

  programs.kitty = {
    enable = true;

    # Codelia vient d'age/fonts (dechiffree dans ~/.local/share/fonts), donc pas
    # de package a installer ici.
    font = {
      name = "Codelia";
      size = 12;
    };

    settings = {
      auto_reload_config = "0.1";
      text_composition_strategy = "1.5 0";
      # SGR 2 (faint) melange le premier plan vers le fond. Le defaut 0.4 laisse
      # le texte dim a 1.9:1 sur le fond Latte, illisible ; 0.8 reste nettement
      # plus pale que le texte normal tout en passant le contraste.
      dim_opacity = "0.8";
      window_padding_width = 2;
    };
  };

  # Plasma 6 n'expose pas d'option plasma-manager pour ca ; le KCM « Applications
  # par defaut » ecrit ces deux cles. TerminalApplication est l'heritage Plasma 5,
  # TerminalService le .desktop que consulte Plasma 6.
  programs.plasma.configFile.kdeglobals.General = {
    TerminalApplication = "kitty";
    TerminalService = "kitty.desktop";
  };
}
```

- [ ] **Step 2 : vérifier que ça évalue**

```bash
nixos-rebuild dry-build --flake .#framework-gab
```

Attendu : termine sans erreur.

- [ ] **Step 3 : vérifier que `kitty.conf` n'a plus d'`include` de thème**

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.framework-gab.config.home-manager.users.gaugendre.xdg.configFile."kitty/kitty.conf".source' \
  | xargs grep -n "include\|color0"
```

Attendu : **aucune sortie**. L'`include` du module amont a disparu, et les huit corrections ne sont plus dans `kitty.conf`.

- [ ] **Step 4 : vérifier le fichier clair**

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.framework-gab.config.home-manager.users.gaugendre.xdg.configFile."kitty/light-theme.auto.conf".source' \
  | xargs grep -n "^background\|^color0 \|^color7 "
```

Attendu : `background #EFF1F5`, `color0  #9CA0B0`, `color7  #4C4F69` — le thème amont suivi des corrections.

- [ ] **Step 5 : vérifier le fichier sombre**

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.framework-gab.config.home-manager.users.gaugendre.xdg.configFile."kitty/dark-theme.auto.conf".source' \
  | xargs grep -n "^background\|^color0 "
```

Attendu : `background #1E1E2E` et `color0 #45475A` — Mocha amont, sans correction.

- [ ] **Step 6 : appliquer et vérifier à l'œil**

```bash
nh os switch .
```

Bascule l'apparence système clair ↔ sombre. kitty doit changer de palette immédiatement, sans redémarrage.

- [ ] **Step 7 : commit**

```bash
git add modules/home/gaugendre/desktop/kitty.nix
git commit -m "kitty: basculer la palette Catppuccin avec le theme systeme"
```

---

### Task 3 : herdr, claude et bat suivent le terminal

**Files:**
- Create: `modules/home/shared/theme-auto.nix`
- Modify: `modules/home/shared/default.nix`
- Modify: `modules/home/gaugendre/desktop/ai-agents.nix`

**Interfaces:**
- Consumes: la bascule de palette kitty de la tâche 2.
- Produces: le fichier `modules/home/shared/theme-auto.nix`, importé par `shared/default.nix`. Les tâches 4 et 5 y ajoutent leurs blocs. Il expose dans son `let` la variable `sources = config.catppuccin.sources;` que les tâches suivantes réutilisent.

- [ ] **Step 1 : créer `modules/home/shared/theme-auto.nix`**

```nix
# Bascule automatique Catppuccin latte/mocha, pilotee par la couleur de fond du
# terminal. Ce module est partage par gaugendre et root sur toutes les machines :
# c'est ce qui fait que les sessions SSH vers srv-1 suivent aussi, puisque la
# requete OSC 11 traverse sshd comme n'importe quels octets sur le pty.
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
in
{
  # bat 0.26 sait choisir seul entre un theme clair et un theme sombre en
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
}
```

Note : `lib` et `pkgs` ne sont pas encore utilisés à cette étape — les tâches 4 et 5 s'en servent. Les garder dans la signature dès maintenant évite d'y revenir.

- [ ] **Step 2 : importer le module**

Dans `modules/home/shared/default.nix`, ajouter `./theme-auto.nix` à la liste `imports`, après `./fresh.nix` :

```nix
  imports = [
    ./fish.nix
    ./bat.nix
    ./eza.nix
    ./starship.nix
    ./helix.nix
    ./fresh.nix
    ./theme-auto.nix
  ];
```

- [ ] **Step 3 : vérifier que bat évalue sur les trois machines**

```bash
nixos-rebuild dry-build --flake .#framework-gab
nixos-rebuild dry-build --flake .#srv-1
```

Attendu : les deux terminent sans erreur.

- [ ] **Step 4 : vérifier la config bat générée**

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.srv-1.config.home-manager.users.gaugendre.xdg.configFile."bat/config".source' \
  | xargs cat
```

Attendu : trois lignes `--theme="auto"`, `--theme-dark="Catppuccin Mocha"`, `--theme-light="Catppuccin Latte"`.

- [ ] **Step 5 : herdr et claude**

Dans `modules/home/gaugendre/desktop/ai-agents.nix`, remplacer le bloc du commentaire et de `xdg.configFile."herdr/config.toml"` :

```nix
  # Pas de module home-manager pour herdr, donc le TOML a la main. herdr s'abonne
  # a OSC 2031 et relaie la couleur de fond de kitty aux enfants des panes, donc
  # auto_switch suffit a le faire suivre.
  xdg.configFile."herdr/config.toml".text = ''
    onboarding = false

    [theme]
    auto_switch = true
    dark_name = "catppuccin-mocha"
    light_name = "catppuccin-latte"

    [ui]
    agent_panel_sort = "priority"
    show_agent_labels_on_pane_borders = true
    mouse_capture = true

    [ui.toast]
    delivery = "system"

    [terminal]
    default_shell = "${lib.getExe pkgs.fish}"
  '';
```

Et dans le bloc `settings`, remplacer `theme = "light";` par :

```nix
      # « Auto (match terminal) » : claude interroge OSC 11 avec repli sur
      # COLORFGBG. Confirme au demarrage d'une session.
      theme = "auto";
```

Le commentaire ligne 23-24, qui dit que herdr n'a pas de thème catppuccin, devient faux — le remplacer par :

```nix
  # herdr : pas de module home-manager en release-26.05, donc juste le paquet.
  # Son theme est configure plus bas, dans herdr/config.toml.
```

- [ ] **Step 6 : vérifier**

```bash
nixos-rebuild dry-build --flake .#framework-gab
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.framework-gab.config.home-manager.users.gaugendre.xdg.configFile."herdr/config.toml".source' \
  | xargs grep -n "auto_switch\|dark_name\|light_name"
```

Attendu : `auto_switch = true`, `dark_name = "catppuccin-mocha"`, `light_name = "catppuccin-latte"`.

- [ ] **Step 7 : appliquer et vérifier à l'œil**

```bash
nh os switch .
```

Redémarre herdr. Bascule l'apparence système : l'interface de herdr doit suivre. Lance `bat` sur un fichier source dans les deux modes : le thème doit changer.

- [ ] **Step 8 : commit**

```bash
git add modules/home/shared/theme-auto.nix modules/home/shared/default.nix \
        modules/home/gaugendre/desktop/ai-agents.nix
git commit -m "herdr, claude, bat: suivre le theme du terminal"
```

---

### Task 4 : fish bascule ses couleurs tout seul

fish 4.7 peuple `$fish_terminal_color_theme` via OSC 11. Un fichier `.theme` comportant des sections `[light]` / `[dark]` / `[unknown]` fait que `fish_config theme choose` installe lui-même un hook `--on-variable` qui réapplique la bonne variante. Les fichiers amont sont plats, il faut donc les fusionner.

**Files:**
- Modify: `modules/home/shared/theme-auto.nix`

**Interfaces:**
- Consumes: `sources` du `let` créé en tâche 3.
- Produces: le thème fish installé à `~/.config/fish/themes/catppuccin.theme`, et l'entrée `programs.fish.interactiveShellInit` qui le choisit. La tâche 5 ajoute son hook dans le même `interactiveShellInit`.

- [ ] **Step 1 : ajouter la génération du thème dans le `let`**

Dans `modules/home/shared/theme-auto.nix`, après `sources = config.catppuccin.sources;` :

```nix
  fishThemeFor = flavor: "${sources.fish}/static/catppuccin-${flavor}.theme";

  # Les fichiers amont sont plats. fish veut un seul fichier a sections : il y
  # installe alors de lui-meme un hook --on-variable fish_terminal_color_theme
  # qui reapplique la bonne variante a chaque changement, dans tous les shells
  # ouverts. [unknown] = terminal qui ne repond pas (pas de tty, lien lent) : on
  # retombe sur le clair, la saveur figee jusqu'ici.
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
```

- [ ] **Step 2 : ajouter la configuration fish**

Dans le corps du module, après le bloc `programs.bat` :

```nix
  catppuccin.fish.enable = false;

  xdg.configFile."fish/themes/catppuccin.theme".source = fishTheme;

  # mkAfter : doit passer apres l'init de fish lui-meme.
  programs.fish.interactiveShellInit = lib.mkAfter ''
    fish_config theme choose catppuccin
  '';
```

- [ ] **Step 3 : vérifier que ça évalue**

```bash
nixos-rebuild dry-build --flake .#framework-gab
nixos-rebuild dry-build --flake .#srv-1
```

Attendu : les deux terminent sans erreur.

- [ ] **Step 4 : vérifier la structure du thème généré**

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.srv-1.config.home-manager.users.gaugendre.xdg.configFile."fish/themes/catppuccin.theme".source' \
  | xargs grep -n "^\[light\]\|^\[dark\]\|^\[unknown\]\|^fish_color_normal"
```

Attendu : les trois en-têtes de section dans cet ordre, et trois occurrences de `fish_color_normal` — `4c4f69` sous `[light]`, `cdd6f4` sous `[dark]`, `4c4f69` sous `[unknown]`.

- [ ] **Step 5 : vérifier que l'ancien appel amont a disparu**

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.srv-1.config.home-manager.users.gaugendre.xdg.configFile."fish/config.fish".source' \
  | xargs grep -n "theme choose"
```

Attendu : une seule ligne, `fish_config theme choose catppuccin`. Pas de `catppuccin-latte`.

- [ ] **Step 6 : appliquer et vérifier à l'œil**

```bash
nh os switch .
```

Ouvre un nouveau pane. `echo $fish_terminal_color_theme` doit répondre `light` ou `dark` selon l'apparence système. Bascule l'apparence : les couleurs de fish doivent suivre **dans le pane déjà ouvert**, sans relancer le shell.

- [ ] **Step 7 : commit**

```bash
git add modules/home/shared/theme-auto.nix
git commit -m "fish: theme Catppuccin a sections claire et sombre"
```

---

### Task 5 : starship, eza et helix via le hook fish

Ces trois-là n'ont aucune détection propre. starship et eza lisent une variable d'environnement à chaque invocation ; helix est un process long qui relit sa configuration sur `SIGUSR1`.

Point vérifié pendant le spike, et qui dicte la forme de la solution : **`SIGUSR1` fait relire `config.toml` à helix et réapplique le thème qui y est nommé**, en jetant tout override runtime. Le nom doit donc rester constant (`catppuccin`) et c'est le *fichier* `catppuccin.toml` qui change de `inherits`.

**Files:**
- Modify: `modules/home/shared/theme-auto.nix`
- Modify: `modules/home/shared/helix.nix`

**Interfaces:**
- Consumes: `sources`, `fishTheme` et l'entrée `interactiveShellInit` de la tâche 4.
- Produces: la fonction fish `__theme_auto`, enregistrée sur `--on-variable fish_terminal_color_theme` et appelée une fois à la définition.

- [ ] **Step 1 : côté helix, pointer sur le thème indirect et installer les deux saveurs**

Dans `modules/home/shared/helix.nix`, remplacer la signature et ajouter ce qu'il faut. Le fichier devient :

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  sources = config.catppuccin.sources;
  helixThemeFor = flavor: "${sources.helix}/no_italics/catppuccin_${flavor}.toml";

  # Amorce : si le hook fish n'a jamais tourne (premiere activation, session sans
  # fish, root), il faut quand meme que catppuccin.toml existe, sinon helix ne
  # trouve pas son theme et repart sur celui par defaut.
  defaultAutoTheme = pkgs.writeText "catppuccin-auto.toml" ''
    inherits = "catppuccin-latte"
  '';
in
{
  # Le module amont ne poserait qu'une saveur et nommerait le theme d'apres elle.
  catppuccin.helix.enable = false;

  xdg.configFile = {
    "helix/themes/catppuccin-latte.toml".source = helixThemeFor "latte";
    "helix/themes/catppuccin-mocha.toml".source = helixThemeFor "mocha";
  };

  # catppuccin.toml n'est pas gere par home-manager : c'est le hook fish qui
  # l'ecrit. On se contente de l'amorcer s'il manque.
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
      # Nom constant : SIGUSR1 fait relire config.toml a helix et reapplique le
      # theme qui y est nomme. C'est donc le fichier catppuccin.toml qui change
      # de `inherits`, pas ce nom.
      theme = "catppuccin";
      editor = {
        line-number = "relative";
        bufferline = "multiple";
        cursorline = true;
        color-modes = true;
        # COLORTERM n'est pas transmis par SSH, et le terminfo de xterm-256color
        # n'annonce pas RGB : sur srv-1 la detection de helix echoue, il refuse
        # tout theme Catppuccin en silence et repart sur son theme par defaut.
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
```

- [ ] **Step 2 : côté theme-auto, générer les configs starship et eza**

Dans le `let` de `modules/home/shared/theme-auto.nix`, après `fishTheme` :

```nix
  tomlFormat = pkgs.formats.toml { };

  # starship est un process par prompt : changer STARSHIP_CONFIG suffit, l'effet
  # est au prompt suivant. Le ~/.config/starship.toml ecrit par le module reste
  # la version claire, donc seule la sombre a besoin d'un fichier dedie.
  starshipMocha = tomlFormat.generate "starship-mocha.toml" (
    config.programs.starship.settings
    // { palette = "catppuccin_mocha"; }
    // lib.importTOML "${sources.starship}/mocha.toml"
  );

  ezaThemeFor =
    flavor:
    pkgs.runCommand "eza-theme-${flavor}" { } ''
      mkdir -p $out
      cp ${sources.eza}/${flavor}/catppuccin-${flavor}-${config.catppuccin.accent}.yml $out/theme.yml
    '';
```

- [ ] **Step 3 : côté theme-auto, poser les fichiers clairs par défaut**

Dans le corps du module, après le bloc fish :

```nix
  catppuccin.starship.enable = false;
  catppuccin.eza.enable = false;

  # Saveur claire par defaut, aux emplacements standards : c'est ce que voient
  # bash, root et tout shell ou le hook n'a pas tourne.
  programs.starship.settings = {
    palette = "catppuccin_latte";
  } // lib.importTOML "${sources.starship}/latte.toml";

  xdg.configFile."eza/theme.yml".source = "${ezaThemeFor "latte"}/theme.yml";
```

- [ ] **Step 4 : côté theme-auto, écrire le hook**

Toujours dans le corps, remplacer le bloc `programs.fish.interactiveShellInit` de la tâche 4 par celui-ci, qui contient les deux morceaux :

```nix
  programs.fish.interactiveShellInit = lib.mkAfter ''
    fish_config theme choose catppuccin

    # starship, eza et helix n'ont aucune detection propre. fish, lui, pose
    # fish_terminal_color_theme des que le terminal a repondu a OSC 11 : on s'y
    # accroche. L'appel explicite en fin de bloc couvre le cas ou la variable est
    # deja posee au moment ou la fonction est definie.
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
        # N'ecrire et ne signaler que si ca change : sinon chaque nouveau shell
        # enverrait un SIGUSR1 a tous les helix ouverts.
        if test "$(cat $themeFile 2>/dev/null)" != "$want"
            echo $want > $themeFile
            ${pkgs.procps}/bin/pkill -USR1 -x hx
        end
        return 0
    end
    __theme_auto
  '';
```

- [ ] **Step 5 : vérifier que ça évalue sur les trois machines**

```bash
nixos-rebuild dry-build --flake .#framework-gab
nixos-rebuild dry-build --flake .#desktop-gab
nixos-rebuild dry-build --flake .#srv-1
```

Attendu : les trois terminent sans erreur.

`starshipMocha` lit `config.programs.starship.settings` dans le module qui écrit aussi cette option : ce n'est pas une récursion, parce que `programs.starship.settings` ne référence jamais `starshipMocha` en retour. Le point de fixe se résout. `//` étant superficiel, le fichier mocha généré porte `palette = "catppuccin_mocha"` et la seule table `palettes.catppuccin_mocha`.

- [ ] **Step 6 : vérifier les deux palettes starship**

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.srv-1.config.home-manager.users.gaugendre.xdg.configFile."starship.toml".source' \
  | xargs grep -n '^palette'
```

Attendu : `palette = "catppuccin_latte"`.

- [ ] **Step 7 : vérifier le hook généré**

```bash
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.srv-1.config.home-manager.users.gaugendre.xdg.configFile."fish/config.fish".source' \
  | xargs grep -n "__theme_auto\|STARSHIP_CONFIG\|pkill"
```

Attendu : la définition de la fonction, l'appel final `__theme_auto`, les deux `set -gx STARSHIP_CONFIG` / `set -e STARSHIP_CONFIG`, et le `pkill -USR1 -x hx` avec un chemin absolu vers le store.

- [ ] **Step 8 : appliquer et vérifier à l'œil**

```bash
nh os switch .
```

Dans un nouveau pane, ouvrir `hx` sur un fichier. Dans un autre pane, basculer l'apparence système. Attendu : le prompt starship change de palette au prompt suivant, `eza -l` change de couleurs, et helix bascule **sans être relancé**. Vérifier aussi que `cat ~/.config/helix/themes/catppuccin.toml` suit.

- [ ] **Step 9 : commit**

```bash
git add modules/home/shared/theme-auto.nix modules/home/shared/helix.nix
git commit -m "starship, eza, helix: suivre le theme via un hook fish"
```

---

### Task 6 : déploiement srv-1 et documentation

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces: rien.

- [ ] **Step 1 : déployer srv-1**

```bash
nixos-rebuild switch --flake .#srv-1 --target-host srv-1 --use-remote-sudo
```

Sans ça, srv-1 garde l'ancienne configuration et rien ne suit côté serveur.

- [ ] **Step 2 : vérifier srv-1 depuis un pane herdr**

```fish
ssh srv-1
```

Puis, dans le fish distant :

```fish
echo $fish_terminal_color_theme
```

Attendu : `light` ou `dark` selon l'apparence système courante. Bascule l'apparence pendant que la session est ouverte : la valeur et les couleurs doivent suivre en live.

- [ ] **Step 3 : vérifier les tools restants sur srv-1**

Toujours dans la session SSH, regarder si le prompt starship et `bat` ont l'air justes dans les deux modes.

```fish
bat ~/.config/fish/config.fish
```

Si les couleurs semblent dégradées, c'est la cause racine notée dans la spec : `COLORTERM` n'est pas transmis par SSH et d'autres outils que helix ont leur propre détection. Le noter, ne pas le corriger dans ce chantier.

- [ ] **Step 4 : mettre à jour `CLAUDE.md`**

Dans la section `## Architecture`, sous `### Key Patterns`, remplacer la puce qui commence par `Catppuccin theming is enabled on desktops` par :

```markdown
- Catppuccin theming is enabled on desktops (`catppuccin.enable = true`). srv-1 does **not** load `catppuccin.nixosModules.catppuccin` at the NixOS level (only the home-manager module via gaugendre).
- The **terminal** stack does not use the fixed `lib/catppuccin.nix` flavor: it follows the system light/dark theme at runtime. kitty reads the XDG portal and applies `~/.config/kitty/*-theme.auto.conf`; herdr relays OSC 11 to pane children; fish, bat and claude detect it themselves; a fish hook drives starship, eza and helix. The shared logic lives in `modules/home/shared/theme-auto.nix`, which is why SSH sessions to srv-1 follow too. `lib/catppuccin.nix` stays `latte` as the fallback for everything else (zed, vscode, thunderbird, plymouth, sddm). See `docs/superpowers/specs/2026-09-18-terminal-theme-auto-switch-design.md`.
- A running kitty will not pick up a **content** change to a theme file across a rebuild: `ThemeColors.refresh()` only re-reads when the mtime grows, and nix store mtimes are fixed. Restart kitty after a rebuild that changes theme content. Flavor switching itself is live.
```

- [ ] **Step 5 : vérifier une dernière fois les trois machines**

```bash
nixos-rebuild dry-build --flake .#framework-gab
nixos-rebuild dry-build --flake .#desktop-gab
nixos-rebuild dry-build --flake .#srv-1
```

Attendu : les trois terminent sans erreur.

- [ ] **Step 6 : commit**

```bash
git add CLAUDE.md
git commit -m "docs: decrire la bascule automatique du theme terminal"
```

---

## Reste à faire, hors de ce plan

- **`fresh-editor`** (`modules/home/shared/fresh.nix`) n'a pas été inspecté côté thème. À regarder une fois le reste en place.
- **Bascule native de helix.** Le thème indirect `inherits` + `SIGUSR1` est la seule logique impérative du design. La fonctionnalité native existe dans les builds de développement (issue upstream <https://github.com/helix-editor/helix/issues/8899>), la release suivant la 25.07.1 devrait l'embarquer. À chaque bump de helix dans le flake : vérifier, et le cas échéant supprimer le thème indirect, le `pkill -USR1` et la moitié helix du hook.
- **`COLORTERM` perdu en SSH.** La tâche 1 traite le seul symptôme constaté. Si l'étape 3 de la tâche 6 montre que fish ou bat sont dégradés sur srv-1, traiter la cause racine dans un chantier séparé.
