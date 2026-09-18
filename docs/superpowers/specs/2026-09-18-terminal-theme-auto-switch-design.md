# Bascule automatique Catppuccin Latte ↔ Mocha du setup terminal

Date : 2026-09-18
Statut : design validé, spike terminé, implémentation à faire

## Problème

`lib/catppuccin.nix` fige `flavor = "latte"` pour le système, `gaugendre` et `root`.
Chaque module catppuccin écrit une seule saveur au moment du build : rien ne bascule à
l'exécution. Le décalage est visible dès aujourd'hui — Plasma a
`AutomaticLookAndFeel=true` et le portail XDG répond `color-scheme = 1` (préférence
sombre) pendant que le terminal reste en Latte.

Objectif : que l'ensemble du setup terminal suive le thème système, **y compris dans les
sessions SSH vers srv-1**.

## Principe

Une seule source de vérité : **la couleur de fond du terminal**. kitty lit le portail XDG
et bascule seul ; herdr relaie aux panes ; tout ce qui sait interroger OSC 11 suit
gratuitement. Le reste est piloté par un hook fish.

```
portail XDG (color-scheme) → kitty (*.auto.conf) → OSC 2031/11 → herdr → panes
                                                                          ├─ fish   (natif)
                                                                          ├─ bat    (natif)
                                                                          ├─ claude (natif)
                                                                          └─ hook fish → starship, eza, helix
                                                                          └─ ssh srv-1 → idem, côté distant
```

Pas de démon systemd, pas d'écoute D-Bus, pas de symlink mutable à arbitrer, pas de
`SendEnv`/`AcceptEnv`.

## Résultats du spike (phase 0)

Tout a été vérifié avant d'écrire une ligne de configuration.

| # | Point vérifié | Résultat |
|---|---|---|
| 1 | `$fish_terminal_color_theme` bascule à chaud dans un pane herdr | ✅ |
| 2 | OSC 11 traverse Tailscale SSH jusqu'à srv-1 | ✅ et **en live** |
| 3 | claude `theme = "auto"` | ✅ au démarrage |
| 4 | helix relit son thème sur `SIGUSR1` | ✅ dans les deux sens |
| 5 | kitty lit les `*.auto.conf` liés vers le store | ✅ avec réserve (voir Limites) |

Constats annexes, acquis pendant le spike :

- **herdr relaie la vraie couleur de fond de kitty.** Sonde OSC 11 dans un pane :
  `\x1b]11;rgb:efef/f1f1/f5f5\x1b\\` = `#EFF1F5` = Catppuccin Latte base, puis
  `rgb:1e1e/1e1e/2e2e` = `#1E1E2E` = Mocha base après bascule. Ce n'est pas une valeur
  en dur.
- **`SIGUSR1` sur helix déclenche `refresh_config`**, qui relit `config.toml` et
  réapplique **le thème qui y est nommé**, en jetant tout override runtime posé par
  `:theme`. C'est ce qui impose de mettre l'indirection dans le *fichier* de thème, et ce
  qui disqualifie toute approche par `:theme`.
- **srv-1 tourne déjà fish 4.7.1 et bat 0.26.1** — les versions qui portent les sections
  `[light]`/`[dark]` et `--theme=auto`. Le rebuild ne sert qu'à poser la nouvelle config.
- **`~/.config/helix/themes/` est un vrai répertoire inscriptible**, peuplé de symlinks
  fichier par fichier. Le hook peut y écrire `catppuccin.toml` sans conflit avec
  home-manager.
- **`COLORTERM` n'est pas transmis par SSH.** Sur srv-1, helix refuse donc tout thème
  Catppuccin en silence et repart sur son thème par défaut. Bug préexistant, indépendant
  de ce chantier, corrigé ici en préalable.

## Mécanismes natifs exploités

Ces comportements existent en amont ; on se contente de les activer.

- **kitty 0.48** applique `~/.config/kitty/{dark,light,no-preference}-theme.auto.conf`
  selon la préférence système, à chaud et sans redémarrage
  (`kitty/colors.py:33`, `boss.py:3690`).
- **herdr 0.9** s'abonne à OSC 2031, expose `[theme] auto_switch / dark_name / light_name`,
  et relaie la couleur de fond hôte aux enfants des panes
  (`pane::osc::write_host_default_color`).
- **fish 4.7** peuple `$fish_terminal_color_theme` via OSC 11. Un fichier `.theme`
  comportant des sections `[light]` / `[dark]` / `[unknown]` fait que
  `fish_config theme choose` installe lui-même un hook
  `--on-variable fish_terminal_color_theme` qui réapplique la bonne variante
  (`fish_config.fish:303`).
- **bat 0.26** accepte `--theme=auto` avec `--theme-dark` / `--theme-light`.
- **claude code** propose `theme = "auto"` (« Auto (match terminal) »), détecté par OSC 11
  avec repli sur `COLORFGBG`.

## Couche 1 — natif, aucune logique

| Outil | Changement |
|---|---|
| kitty | `catppuccin.kitty.enable = false` (il pose un `include` figé). À la place, les trois `*.auto.conf`. Les corrections de palette Latte ne vont que dans le fichier clair. `no-preference` → Latte. |
| herdr | `[theme] auto_switch = true`, `dark_name = "catppuccin-mocha"`, `light_name = "catppuccin-latte"`. |
| fish | `catppuccin.fish.enable = false`. Un `.theme` fusionné généré en Nix depuis `config.catppuccin.sources.fish` : `[light]` ← latte, `[dark]` ← mocha, `[unknown]` ← latte. `fish_config theme choose catppuccin` dans `shellInit`. |
| bat | `catppuccin.bat.enable = false`. `theme = "auto"`, `theme-dark = "Catppuccin Mocha"`, `theme-light = "Catppuccin Latte"`, les deux `themes.*` installés depuis `sources.bat`. |
| claude | `settings.theme = "auto"`. |

### Corrections de palette kitty

Les huit clés corrigées aujourd'hui dans `kitty.nix` (`color0/8` → overlay0,
`color5/13` → mauve, `color6/14` → sky, `color7/15` → couleur de texte) sont **spécifiques
à Latte**. La palette Mocha amont est saine : `color0` = surface1, `color5` = pink,
`color6` = teal, `color7` = subtext1, tous lisibles sur base sombre. Le commentaire
« À revoir si on repasse en Mocha » disparaît : la réponse est non.

## Couche 2 — le hook fish comme répartiteur

Une fonction enregistrée sur `--on-variable fish_terminal_color_theme`, appelée aussi une
fois au démarrage du shell (la variable peut déjà être posée quand la fonction est
définie).

| Outil | Levier | Latence |
|---|---|---|
| starship | `set -gx STARSHIP_CONFIG` vers l'un des deux `starship.toml` générés | prompt suivant — starship est un process par prompt |
| eza | `set -gx EZA_CONFIG_DIR` | invocation suivante |
| helix | écrit `~/.config/helix/themes/catppuccin.toml` (`inherits = "catppuccin-latte|mocha"`) puis `pkill -USR1 hx` | immédiat |

Les trois modules amont correspondants sont désactivés — `catppuccin.starship.enable`,
`catppuccin.eza.enable` et `catppuccin.helix.enable` à `false` — puisqu'ils écrivent une
saveur unique là où il en faut deux.

Pour helix, home-manager installe `catppuccin-latte.toml` **et**
`catppuccin-mocha.toml`, et `config.toml` porte `theme = "catppuccin"`. Le nom
`catppuccin.toml` n'étant pas géré par home-manager, le hook peut l'écrire sans conflit.

Le hook n'écrit le fichier et n'envoie le signal que si le contenu change, pour éviter les
courses entre shells et les `SIGUSR1` inutiles.

## Emplacement des modules

C'est ce découpage qui donne SSH gratuitement.

| Module | Emplacement | Portée |
|---|---|---|
| `theme-auto.nix` *(nouveau)* | `modules/home/shared/` | gaugendre + root, **tous les hôtes, srv-1 compris** |
| `*.auto.conf` kitty | `modules/home/gaugendre/desktop/kitty.nix` | poste seulement |
| herdr + claude | `modules/home/gaugendre/desktop/ai-agents.nix` | poste seulement |

`modules/home/shared/` est déjà importé par `gaugendre/home.nix`, lui-même chargé par
`modules/nixos/common/home-manager.nix` — donc srv-1 reçoit fish, starship, helix, bat et
eza depuis exactement les mêmes modules que le poste. Le hook s'exécute dans le fish
**distant** : il y pose les variables d'environnement et le `catppuccin.toml`. Rien n'est
transporté par SSH à part les octets OSC.

`lib/catppuccin.nix` conserve `flavor = "latte"` comme saveur de repli pour tout le
non-terminal.

## Comportement de repli

Sans réponse OSC 11 — pas de tty, `ssh srv-1 <commande>` sans terminal, lien trop lent —
`$fish_terminal_color_theme` vaut `unknown`, la section `[unknown]` du `.theme` s'applique
et tout retombe en Latte. C'est le comportement actuel : aucune régression.

## Limites assumées

- **kitty et les mtime du store.** `ThemeColors.refresh()` ne relit un fichier que si sa
  mtime a augmenté, or elle est figée dans le nix store. Après un rebuild qui change le
  *contenu* d'un thème, une instance kitty déjà lancée garde l'ancienne palette jusqu'à
  redémarrage. La bascule Latte ↔ Mocha, elle, reste à chaud.
- **claude en cours de session, dans un pane herdr.** Le thème `auto` prend toujours la
  bonne saveur au démarrage, quelle que soit celle du système. En fenêtre kitty simple, il
  suit aussi les bascules à chaud, sans défaut. Dans un pane herdr en revanche il a un cran
  de retard : le fond est déjà clair alors que les couleurs d'accentuation sont encore
  celles du thème sombre, et inversement. Le décalage disparaît à la session suivante.
  C'est une interaction entre le relais OSC 11 de herdr et la redétection de claude — rien
  que la configuration Nix puisse corriger.
- **srv-1 embarque les deux saveurs** dans sa closure (quelques centaines de Ko de
  fichiers de thème).
- **srv-1 doit être redéployé** pour recevoir la nouvelle configuration.

## Hors périmètre

zed, vscode, thunderbird, plymouth, sddm et konsole restent en Latte figé. konsole garde
ses deux profils latte/mocha en place, inutilisés.

## Découpage en phases

**Préalable — correctif helix true-color.** `editor.true-color = true` dans
`modules/home/shared/helix.nix`, avec un commentaire expliquant que `COLORTERM` n'est pas
transmis par SSH et que le terminfo de `xterm-256color` ne suffit pas. Ne dépend de rien,
répare srv-1 immédiatement, commit autonome.

**Phase 1 — kitty.** Les trois `*.auto.conf`, corrections Latte isolées dans le fichier
clair, `catppuccin.kitty.enable = false`, `extraConfig` supprimé.

**Phase 2 — herdr, claude, bat.** Trois réglages déclaratifs, aucune logique.

**Phase 3 — fish.** Génération du `.theme` fusionné, `catppuccin.fish.enable = false`.

**Phase 4 — starship, eza, helix.** Le hook et les jeux de configuration doubles.

**Phase 5 — déploiement srv-1 et nettoyage.** `nh os switch` sur srv-1, mise à jour de la
section catppuccin de `CLAUDE.md` qui ne décrira plus la réalité, vérification que `root`
et srv-1 évaluent toujours correctement, et coup d'œil au thème de `fresh-editor`, non
inspecté à ce jour.

## À revisiter

- **helix : bascule clair/sombre native.** Le thème indirect `inherits` + `SIGUSR1` est la
  seule logique impérative de tout le design. La fonctionnalité native existe déjà dans
  les builds de développement de helix (issue upstream
  <https://github.com/helix-editor/helix/issues/8899>) ; la release suivant la 25.07.1
  devrait l'embarquer. À chaque bump de helix dans le flake, vérifier et, le cas échéant,
  supprimer le thème indirect, le `pkill -USR1` et la moitié helix du hook fish.
- **Le cran de retard de claude dans un pane herdr.** Isolé à l'interaction herdr ↔ claude :
  la même bascule est parfaite en fenêtre kitty simple. À remonter en amont si ça devient
  gênant, ou à retester à chaque montée de version de herdr ou de claude.
- **`COLORTERM` perdu en SSH, cause racine.** Le correctif helix traite le seul symptôme
  constaté. fish (`fish_term24bit`), bat et d'autres ont leur propre détection et sont
  peut-être dégradés eux aussi sur srv-1. À mesurer en phase 5 avant de généraliser : si
  le prompt starship et `bat` ont l'air justes sur srv-1, on s'arrête là.
