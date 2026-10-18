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

- Chaque lundi, le workflow `update-flake-lock` met `flake.lock` à jour, builde srv-1 avant
  et après, et ouvre la PR `flake.lock: update` avec le diff de paquets (dix). Si la PR n'est
  pas mergée avant le run suivant, elle est mise à jour, pas dupliquée. Lancement manuel :
  `gh workflow run update-flake-lock.yml`.
- Chaque nuit à 04:00, srv-1 applique `main` (`hosts/srv-1/auto-upgrade.nix`) et redémarre
  entre 04:00 et 06:00 si le kernel ou l'initrd a changé.

Réglages faits à la main, une seule fois :

- GitHub, *Settings → Actions → General* : cocher « Allow GitHub Actions to create and approve
  pull requests », sinon le workflow ne peut pas ouvrir la PR.
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
