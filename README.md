# nixos-config

Configuration NixOS de **srv-1**, le seul hôte encore sous NixOS. Les desktops tournent sous
Arch (`arch-config` et les dotfiles chezmoi) et ne lisent rien de ce repo, sauf la fonction fish
`agenix` des dotfiles, qui épingle agenix sur ce flake (`nix run --inputs-from`).

## Directory Structure

- **`hosts/srv-1/`** : point d'entrée (`configuration.nix`), disque (disko), réseau, secrets
  (`age/`) et services (`services/`).
- **`modules/nixos/common/`** : base système (réglages nix, fish, paquets de base, utilisateurs,
  home-manager).
- **`modules/home/gaugendre/`** : configuration Home Manager de gaugendre.
- **`modules/home/shared/`** : modules Home Manager partagés par gaugendre et root (fish, bat,
  eza, starship, helix, fresh, theme-auto).
- **`modules/home/root/`** : configuration Home Manager de root.
- **`lib/`** : `identity.nix` (`fullName` / `email`) et `catppuccin.nix` (saveur partagée).
- **`overlays/`** : overlays nixpkgs (paquets tirés de nixpkgs-unstable, downloader).

## Module Hierarchy

```
hosts/srv-1/configuration.nix
  → modules/nixos/common/
      default.nix → save-disk.nix, home-manager.nix, users.nix
                      → modules/home/gaugendre/home.nix → modules/home/shared/
                      → modules/home/root/home.nix      → modules/home/shared/
  → hosts/srv-1/age, hosts/srv-1/services
```

## Deploy

```
mise run srv-1
```

srv-1 récupère depuis GitHub la branche courante (déjà poussée) et se reconstruit lui-même.

## Mises à jour automatiques

- Chaque lundi, le workflow `update-flake-lock` met `flake.lock` à jour et ouvre la PR
  `flake.lock: update`. Si elle n'est pas mergée avant le run suivant, il y ajoute un commit
  (les corrections poussées dessus sont gardées), sans en ouvrir une autre. Lancement manuel :
  `gh workflow run update-flake-lock.yml`.
- Sur chaque PR vers `main` et à chaque push, `pr-build` builde srv-1 avant et après et poste un
  commentaire, mis à jour à chaque run : le diff de paquets (dix), ou l'erreur de build si la PR
  ne builde pas. Ce check est obligatoire pour merger.
- Si `pr-build` échoue sur la PR hebdo, `auto-fix` donne l'erreur à Claude, qui tente **une**
  correction, poussée sur la PR et rebuildée par `pr-build`. Si elle échoue aussi, la main
  revient à un humain.
- Chaque nuit à 04:00, srv-1 applique `main` (`hosts/srv-1/auto-upgrade.nix`) et redémarre
  entre 04:00 et 06:00 si le kernel ou l'initrd a changé.
- Renovate (`renovate.json`) met à jour les GitHub Actions épinglées par SHA, une fois par mois,
  en une seule PR groupée. `flake.lock` n'est pas de son ressort : le manager nix est désactivé.

Réglages faits à la main, une seule fois :

- Secret `FLAKE_UPDATE_TOKEN` : fine-grained PAT limité à ce repo, *Contents* et *Pull
  requests* en lecture/écriture. À recréer à son expiration
  (`gh secret set FLAKE_UPDATE_TOKEN -R Crocmagnon/nixos-config`).
- Secret `CLAUDE_CODE_OAUTH_TOKEN` : `claude setup-token`, valable un an, à recréer ensuite
  (`gh secret set CLAUDE_CODE_OAUTH_TOKEN -R Crocmagnon/nixos-config`).
- Règle de protection de `main` qui exige le check `build` de `pr-build`.
- GitHub : installer l'app [Renovate](https://github.com/apps/renovate) sur ce repo, si ce
  n'est pas déjà fait.
- healthchecks : le check `nixos-upgrade` est créé au premier run ; régler sa période (1 jour)
  et sa grâce.

## Update secrets
```
cd hosts/srv-1/age
agenix -e miniflux-db.age
```

Les dossiers s'appellent `age/` et non `secrets/` : Claude Code refuse de lire quoi que ce soit
sous un segment de chemin nommé `secrets`, ce qui bloquait la lecture des fichiers de règles
eux-mêmes. `.claude/settings.json` interdit à la place ce qui compte vraiment — exécuter
`age`/`agenix` et lire les `*.age`.

Sur les desktops, `agenix` est la fonction fish des dotfiles, qui force
`-i ~/.config/agenix/identity.txt` : une identité age dédiée, sans passphrase. Sans elle, age
réclame la passphrase de `~/.ssh/id_ed25519`. **Cette clé est à sauvegarder** : sans elle (et
sans la clé SSH, toujours destinataire), plus aucun secret n'est déchiffrable.

## Pre-commit hooks

Nix files are auto-formatted with `nixfmt` via a [prek](https://github.com/j178/prek) hook (drop-in replacement for `pre-commit`). After cloning, install the git hook once:

```
prek install
```

Run the hooks manually on all files:

```
prek run --all-files
```
