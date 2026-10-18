# srv-1 auto-update et ménage des desktops — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Réduire le repo à srv-1, puis faire avancer `flake.lock` par une PR hebdo qui montre le diff de paquets, et faire que srv-1 applique seul `main` chaque nuit.

**Architecture:** Deux PR empilées. La PR 1 (`remove-desktops`) supprime tout ce qui ne sert qu'aux desktops ; son test est l'invariance du `drvPath` de srv-1. La PR 2 (`srv-1-auto-update`, basée sur la PR 1) ajoute `system.autoUpgrade` sur srv-1, branché sur `healthchecks@`, et un workflow GitHub Actions qui fait `nix flake update`, lance `dix` entre les deux `drvPath` puis crée ou met à jour la PR avec `peter-evans/create-pull-request`.

**Tech Stack:** NixOS 26.05 flake, module `system.autoUpgrade`, GitHub Actions, dix 2.x.

**Spec:** `docs/superpowers/specs/2026-10-18-srv-1-auto-update-design.md`

## Global Constraints

- Branche par défaut `main`. PR sur GitHub (`gh`). Le repo est public.
- Commits terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, PR par `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Ne jamais lire de `*.age` ni lancer `age` ou `agenix` (`.claude/settings.json`).
- `nixfmt` passe sur les fichiers `.nix` touchés (hook pre-commit).
- Commentaires et docs en français, comme le reste du repo.
- Ne pas déployer sur srv-1 : l'utilisateur déploie, sauf demande explicite.
- `git branch --show-current` dans le même appel que tout `git switch -c`.

## Faits déjà vérifiés (pour ne pas les refaire)

- Le module `system.autoUpgrade` du nixpkgs épinglé ajoute `--refresh --flake <flake>` tout seul quand `flake` est défini.
- Avec `allowReboot`, il fait `nixos-rebuild boot` et compare `/run/booted-system/{initrd,kernel,kernel-modules}` au nouveau système. S'ils sont identiques, il fait un `switch`. Sinon il lance `shutdown -r +1` **puis l'unité se termine avec succès**, donc `onSuccess` part avant le reboot : le ping healthchecks « success » fonctionne aussi les nuits de reboot. Hors de `rebootWindow`, il affiche « Outside of configured reboot window, skipping. » et sort en succès **sans rien appliquer**.
- `dix <old.drv> <new.drv>` fonctionne sans builder. Il affiche les lignes `PATHS`, `SIZE` et `DIFF`. Les sections CHANGED, ADDED et REMOVED restent à confirmer sur un vrai bump (tâche 3).
- L'éval de srv-1 fait de l'IFD : elle builde `whiskers` (Rust) et `catppuccin-starship` faute de cache, et substitue starship.

## Review Focus

1. **Upgrade sauté sans bruit** : si restic (02:00) dure au-delà de 06:00, l'upgrade sérialisé derrière lui démarre hors fenêtre. Un upgrade qui demande un reboot est alors sauté, mais le ping « success » part quand même. Il faut au minimum un log explicite, et ce cas doit être documenté (tâche 2).
2. **Branche de test** : un `mise run srv-1` d'une branche est écrasé la nuit suivante par `main`. C'est attendu, mais il faut le documenter dans `CLAUDE.md` et dans la description de la tâche mise (tâche 2).
3. **Sortie de dix trop longue** : un bump de release peut dépasser 65 536 caractères de corps de PR. Le workflow doit tronquer et dire où lire la suite (tâche 3).
4. **Aucun changement** : si `flake.lock` n'a pas bougé, aucune PR ne doit s'ouvrir ni être réécrite (tâche 3).
5. **Éval cassée après un bump** : le job doit échouer et laisser la PR existante telle quelle (tâche 3).

---

### Task 1: Ménage des desktops (PR 1)

**Files:**
- Delete: `hosts/desktop-gab/`, `hosts/framework-gab/`, `modules/nixos/desktop/`, `modules/home/gaugendre/desktop/`
- Modify: `flake.nix` (hosts et inputs `nixos-hardware`, `plasma-manager`, `nix-flatpak`), `flake.lock` (`nix flake lock` pour retirer ces inputs, **sans** `update`), `overlays/unstable-packages.nix`, `mise.toml` (supprimer `localhost` et `all`), `README.md`, `CLAUDE.md`, `lib/catppuccin.nix` (commentaire seulement s'il cite les desktops), `.claude/settings.json` (retirer la règle `Read(//home/gaugendre/.config/agenix/**)` **uniquement** si plus rien ne la justifie ; dans le doute, la garder)

**Interfaces:**
- Produces : une config où `nixosConfigurations` ne contient que `srv-1`.

- [ ] **Step 1 : renommer la branche et noter la référence**

```bash
git branch -m srv-1-auto-update remove-desktops && git branch --show-current
nix eval --raw .#nixosConfigurations.srv-1.config.system.build.toplevel.drvPath > /tmp/claude-1000/drv-before
```
Attendu : `remove-desktops`, puis un chemin `…-nixos-system-srv-1-….drv`.

- [ ] **Step 2 : supprimer les fichiers et éditer `flake.nix`, l'overlay et `mise.toml`**

Retire de l'overlay chaque paquet que plus rien n'utilise dans ce qui reste (`grep -rn "\b<nom>\b" hosts modules lib`). `btop`, `prek` et `fresh-editor` sont encore utilisés via `modules/home`, `esphome` via srv-1. Ensuite `nix flake lock`.

- [ ] **Step 3 : vérifier l'invariance**

```bash
nix flake check
test "$(nix eval --raw .#nixosConfigurations.srv-1.config.system.build.toplevel.drvPath)" = "$(cat /tmp/claude-1000/drv-before)" && echo SAME
```
Attendu : `SAME`. Sinon, `dix` des deux drv pour trouver ce qui a changé et corriger (un paquet d'overlay retiré à tort, le plus souvent).

- [ ] **Step 4 : réécrire `README.md` et `CLAUDE.md` pour une config mono-serveur**

Retirer : Module Hierarchy desktop, « New Desktop », store agenix desktop et polices, AppImages propriétaires, udev, autostart graphique, kitty (garder la phrase sur theme-auto pour les sessions SSH depuis kitty), plasma, catppuccin NixOS-level. Garder : la fonction fish `agenix` des dotfiles Arch, l'identité age passphrase-less (recipient du store srv-1), `agenix -r` dans `hosts/srv-1/age` seulement.

- [ ] **Step 5 : commit et PR draft**

```bash
git add -A && git commit -m "remove desktop hosts and modules: desktops now run Arch …"
git push -u origin remove-desktops && gh pr create --draft --base main --title "Remove desktop hosts and modules" --body "…"
```

---

### Task 2: auto-upgrade de srv-1

**Files:**
- Create: `hosts/srv-1/auto-upgrade.nix`
- Modify: `hosts/srv-1/configuration.nix` (import), `CLAUDE.md` (section courte « Mises à jour de srv-1 »), `mise.toml` (description de `srv-1` : la nuit suivante remet `main`)

**Interfaces:**
- Consumes : l'unité template `healthchecks@` (`hosts/srv-1/services/healthchecks.nix`, argument `<slug>:<start|success|failure>`) et `restic-backups-local.service`.
- Produces : `nixos-upgrade.service` et `nixos-upgrade.timer`, et le check healthchecks `nixos-upgrade`.

- [ ] **Step 1 : créer la branche sur la PR 1**

```bash
git switch -c srv-1-auto-update && git branch --show-current
```

- [ ] **Step 2 : test d'éval qui échoue**

```bash
nix eval --json .#nixosConfigurations.srv-1.config.systemd.services.nixos-upgrade --apply 's: { inherit (s) wants onSuccess onFailure after; }'
```
Attendu avant l'implémentation : une erreur (`nixos-upgrade` n'existe pas).

- [ ] **Step 3 : écrire `hosts/srv-1/auto-upgrade.nix`**

Valeurs fixées par la spec : `flake = "github:Crocmagnon/nixos-config"`, `dates = "04:00"`, `randomizedDelaySec = "30min"`, `allowReboot = true`, `rebootWindow = { lower = "04:00"; upper = "06:00"; }`. Pour `systemd.services.nixos-upgrade` : `after = [ "restic-backups-local.service" ]`, plus `wants`, `onSuccess` et `onFailure` sur `healthchecks@nixos-upgrade:{start,success,failure}.service`, comme `restic.nix`. Ajouter un commentaire d'une ligne pour chaque raison non évidente : `after` sérialise derrière un restic en cours, qui arrête des services ; hors fenêtre, un upgrade qui demande un reboot est sauté mais signalé comme succès.

- [ ] **Step 4 : le test passe**

Même commande qu'au step 2. Attendu : `after` contient `restic-backups-local.service`, et `wants`, `onSuccess` et `onFailure` pointent sur les trois unités `healthchecks@nixos-upgrade:…`. Puis :
```bash
nix eval --raw .#nixosConfigurations.srv-1.config.systemd.services.nixos-upgrade.script | grep -E -- '--refresh|--flake github:Crocmagnon/nixos-config|04:00|06:00'
```
Attendu : les quatre motifs apparaissent. Lancer aussi `nix flake check`.

- [ ] **Step 5 : docs, commit et PR draft basée sur `remove-desktops`**

Dans `CLAUDE.md`, documenter : ce qui est sur `main` part en prod la nuit (04:00–04:30, Paris), le reboot n'a lieu que si le kernel ou l'initrd change, et dans la fenêtre 04:00–06:00. Une branche testée par `mise run srv-1` est écrasée la nuit suivante. Le check healthchecks `nixos-upgrade` est créé au premier run, sa période doit être réglée à la main. Ajouter le Review Focus n° 1.

```bash
git push -u origin srv-1-auto-update && gh pr create --draft --base remove-desktops --title "srv-1: nightly auto-upgrade and weekly flake.lock PR" --body "…"
```

---

### Task 3: workflow hebdo de bump avec diff dix

**Files:**
- Create: `.github/workflows/update-flake-lock.yml`
- Modify: `README.md` (section « Mises à jour automatiques » : le réglage manuel « Allow GitHub Actions to create and approve pull requests », et le check healthchecks à régler)

**Interfaces:**
- Produces : la branche `update-flake-lock` et une PR titrée `flake.lock: update` vers `main`.

- [ ] **Step 1 : prototyper le cœur en local**

Dans une copie jetable du repo (`git worktree add` dans le scratchpad), lancer `old` eval, `nix flake update nixpkgs`, `new` eval, puis `nix run nixpkgs#dix -- "$old" "$new"`. Attendu : une section listant des paquets avec des versions (par ex. `linux 6.x.a -> 6.x.b`). Si dix n'affiche que `PATHS`, `SIZE` et `DIFF` sur des drv, essayer `nix store diff-closures "$old" "$new"`. Si aucun des deux ne liste de versions sans build, s'arrêter et le signaler (c'est une décision de spec, pas un choix d'implémentation).

- [ ] **Step 2 : écrire le workflow**

- `on: schedule: - cron: "0 3 * * 1"` + `workflow_dispatch`. `permissions: contents: write, pull-requests: write`. Un job, `ubuntu-latest`.
- Actions épinglées par SHA de commit, avec la version en commentaire : `actions/checkout`, une action d'installation de Nix, `peter-evans/create-pull-request`.
- Configurer `extra-substituters = https://catppuccin.cachix.org` avec sa clé publique, prise dans la doc de catppuccin/nix, pour éviter de rebuilder whiskers.
- Steps : eval `old`, puis `nix flake update`, puis eval `new` (un échec fait échouer le job). Ensuite le corps de PR : sortie dix dans un bloc ```` ``` ````, puis la liste des inputs modifiés (ancienne et nouvelle révision courtes, avec la date, tirées de `git diff flake.lock` ou de `nix flake metadata --json` avant et après). Tronquer à 60 000 caractères avec la ligne `… tronqué, sortie complète dans les logs du run`. Écrire le corps dans un fichier.
- `peter-evans/create-pull-request` avec `branch: update-flake-lock`, `base: main`, `title: "flake.lock: update"`, `commit-message: "flake.lock: update"`, `add-paths: flake.lock`, `body-path: <fichier>`, `delete-branch: true`. L'action ne fait rien si `flake.lock` n'a pas changé (Review Focus n° 4).

- [ ] **Step 3 : linter**

```bash
nix run nixpkgs#actionlint -- .github/workflows/update-flake-lock.yml
```
Attendu : aucune sortie, code 0.

- [ ] **Step 4 : commit, push, et passage des deux PR en ready**

Le run réel ne peut se faire qu'une fois le workflow sur `main`. Le dire dans le corps de la PR 2, avec la commande de vérification après merge : `gh workflow run update-flake-lock.yml && gh run watch`. Une PR `flake.lock: update` doit alors apparaître, avec une sortie dix lisible. Un second `gh workflow run` doit mettre à jour **la même** PR, pas en ouvrir une autre.
