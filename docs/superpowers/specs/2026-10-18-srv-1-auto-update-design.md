# Mise à jour automatique de srv-1 et ménage des desktops

## Intention

srv-1 est la seule machine encore sous NixOS : les desktops (`framework-gab`, `desktop-gab`)
tournent sous Arch, configurés par `arch-config` et les dotfiles chezmoi, qui ne lisent plus
rien de ce repo (seule exception : la fonction fish `agenix` fait
`nix run --inputs-from <ce repo> agenix`). Aujourd'hui srv-1 n'est mis à jour que quand
l'utilisateur pense à lancer `mise run flake-update` puis `mise run srv-1` depuis un desktop.
On veut que ça se fasse tout seul, en gardant un geste humain sur le bump des inputs, et que
la PR de bump montre **ce qui change réellement sur la machine** (paquets et versions), pas
seulement le diff de `flake.lock`.

## Objectifs

1. Une PR de bump des inputs, au plus une par semaine, mise à jour (même branche, même PR) si
   elle n'a pas été mergée avant le run suivant, au lieu d'en ouvrir une nouvelle.
2. Le corps de cette PR liste les changements de paquets de srv-1 (sortie de **dix** entre le
   `toplevel` de `main` et celui de la PR), régénéré à chaque run.
3. srv-1 applique seul ce qui est sur `main`, chaque nuit, avec le mécanisme natif
   `system.autoUpgrade`, et redémarre seul la nuit quand le kernel/initrd l'exige.
4. Un échec de l'auto-upgrade est signalé via le healthchecks existant.
5. Le repo ne contient plus que ce qui sert à srv-1.

## Non-objectifs

- Auto-merge de la PR : le merge reste manuel.
- Déploiement poussé depuis la CI (SSH, deploy-rs, colmena…) : srv-1 tire lui-même.
- Commentaire de diff sur les PR écrites à la main : seule la PR de bump est concernée.
- Builder le système en CI ou mettre en place un cache binaire.

## Anti-objectifs

- srv-1 qui modifie son propre `flake.lock` (`--update-input`, `--recreate-lock-file`) : la
  machine doit tourner exactement le lock committé sur `main`.
- Une PR de bump par semaine qui s'empilent.
- Un PAT ou une GitHub App à gérer juste pour déclencher un second workflow.

## Partie 1 — ménage (à faire en premier, PR séparée)

Supprimer :

- `hosts/desktop-gab/`, `hosts/framework-gab/` et leurs entrées dans `flake.nix`.
- `modules/nixos/desktop/` en entier.
- `modules/home/gaugendre/desktop/` en entier, y compris le store agenix desktop
  (`age/`, `age/fonts/`).
- Les inputs qui ne servent plus : `nixos-hardware`, `plasma-manager`, `nix-flatpak`.
  `catppuccin` (homeModule utilisé par gaugendre et root sur srv-1), `nix-index-database`
  (`comma` dans `modules/home/shared`), `agenix`, `disko`, `downloader`, `nixpkgs-unstable`
  restent.
- Dans `overlays/unstable-packages.nix`, les entrées que plus rien n'utilise dans la config
  srv-1 (probablement : gokrazy, claude-code, herdr, prek, mise, koreader, les outils go,
  mcp-nixos, ha-mcp…). Garder ce que srv-1 consomme (esphome au minimum). Le critère est
  vérifiable : grep de l'attribut dans ce qui reste.
- Les tâches mise `localhost` et `all`.
- Le reste qui ne concerne que les desktops : `lib/catppuccin.nix` reste (lu par
  `modules/home/gaugendre/home.nix`), son commentaire est à corriger s'il cite le système
  desktop.

Garder : `modules/home/shared/` tel quel (theme-auto sert aux sessions SSH vers srv-1 depuis
kitty), les specs/plans existants sous `docs/` (historique), la clé SSH `gaugendre@desktop-gab`
dans `users.nix` (le desktop existe toujours sous Arch), les recipients du store srv-1
(`hosts/srv-1/age/secrets.nix`) inchangés : la clé age passphrase-less des desktops reste
ce qui permet d'éditer les secrets serveur.

`modules/nixos/common/` ne sert plus qu'à srv-1 mais **reste un module séparé** (appel du
builder : pas de fusion, diff minimal).

Docs : `README.md` et `CLAUDE.md` réécrits pour une config mono-serveur. Retirer tout ce qui
concerne les desktops (store agenix desktop et polices, AppImages propriétaires/rotatrix,
udev, autostart graphique, kitty, plasma, « New Desktop »). Garder la mention que `agenix`
sur les desktops Arch est la fonction fish du repo dotfiles, utilisée pour éditer les secrets
de srv-1.

Validation : `nix flake check` passe et
`nix build .#nixosConfigurations.srv-1.config.system.build.toplevel --dry-run` (ou
`nix eval --raw …drvPath`) réussit ; le `drvPath` de srv-1 est **identique** avant et après
le ménage, hors entrées `flake.lock` retirées. Si le drvPath change, l'expliquer.

## Partie 2 — bump hebdo avec diff de paquets

Un workflow `.github/workflows/update-flake-lock.yml` :

- Déclencheurs : `schedule` hebdo + `workflow_dispatch`. **Appel du builder** : lundi
  03:00 UTC (05:00 Paris l'été).
- Un seul job, sur `ubuntu-latest`, avec Nix installé par `DeterminateSystems/nix-installer-action`
  ou `cachix/install-nix-action` (au choix du builder, versions épinglées).
- Étapes :
  1. Checkout de `main`.
  2. `nix eval --raw .#nixosConfigurations.srv-1.config.system.build.toplevel.drvPath`
     → `old`.
  3. `nix flake update`.
  4. Même eval → `new`. Un échec d'évaluation fait échouer le job : la PR n'est ni créée ni
     mise à jour, et le run rouge prévient l'utilisateur par mail GitHub.
  5. `dix "$old" "$new"` (via `nix run nixpkgs#dix`, ou le paquet du nixpkgs épinglé). Le
     builder vérifie que dix sait comparer des `.drv` sans les builder, comme le fait
     `natsukium/nix-diff-action` en mode par défaut. Si dix exige des outputs réalisés, se
     rabattre sur `nix store diff-closures` des drv, ou sur ce que fait nix-diff-action, sans
     builder le système.
  6. Corps de PR : la sortie dix dans un bloc de code, puis la liste des inputs qui ont bougé
     (ancienne → nouvelle révision, avec date, au format de `update-flake-lock`). Tronquer
     sous la limite GitHub (65 536 caractères) avec une mention « tronqué, voir les logs du
     run ».
  7. `peter-evans/create-pull-request` (version épinglée) avec une branche fixe
     (`update-flake-lock`), titre `flake.lock: update`, le corps ci-dessus, commit du seul
     `flake.lock`. Sur une PR existante, l'action force-push la branche et réécrit le corps :
     c'est ce qui satisfait l'objectif 1. Si `flake.lock` n'a pas bougé, rien n'est créé.
     `base: main` explicite, sinon un dispatch depuis une autre branche ouvrirait la PR
     contre celle-ci.
- L'éval n'est pas strictement « sans build » : `modules/home/shared/starship.nix` lit un
  fichier de `${pkgs.starship}` (import-from-derivation), donc starship est substitué depuis
  cache.nixos.org pendant l'éval. C'est attendu, ce n'est pas une panne.
- Repo et input `downloader` publics : ni la CI ni srv-1 n'ont besoin de token.
- Permissions : `contents: write`, `pull-requests: write`. Le réglage du repo « Allow GitHub
  Actions to create and approve pull requests » doit être activé : c'est une étape manuelle
  pour l'utilisateur, à écrire dans le README et à signaler à la livraison.
- Le token par défaut ne déclenche pas d'autre workflow sur la PR. C'est voulu : tout se
  passe dans ce job, il n'y a pas d'autre workflow.

Inspiration : <https://www.technowizardry.net/2026/06/comparing-changes-in-a-nix-flake/>
(dix sur le toplevel par host) et
<https://forrestjacobs.com/keeping-nixos-systems-up-to-date-with-github-actions/>.

## Partie 3 — auto-upgrade de srv-1

Dans la config de srv-1 (un fichier `hosts/srv-1/auto-upgrade.nix` importé par
`configuration.nix`, appel du builder) :

```nix
system.autoUpgrade = {
  enable = true;
  flake = "github:Crocmagnon/nixos-config";   # main, lock committé, pas de --update-input
  dates = "04:00";                            # heure locale du serveur (Europe/Paris)
  randomizedDelaySec = "30min";
  allowReboot = true;
  rebootWindow = { lower = "04:00"; upper = "06:00"; };
};
```

- Le module ajoute déjà `--refresh` quand `flake` est défini : le builder le vérifie dans le
  nixpkgs épinglé. Si ce n'est pas le cas, l'ajouter via `flags`.
- `allowReboot` : le module fait `nixos-rebuild boot`, et ne redémarre que si le kernel,
  l'initrd ou les modules du nouveau système diffèrent du système booté. Sinon il fait un
  `switch`. Le builder confirme ce comportement dans le source du module épinglé.
- Horaires (appel du builder) : restic tourne à 02:00 et arrête paperless, servarr et
  calibre. 04:00 lui laisse deux heures. Si restic dure plus longtemps, l'upgrade peut
  redémarrer des services pendant le backup, ou redémarrer la machine en plein backup. Le
  builder ajoute `after = [ "restic-backups-local.service" ]` sur `nixos-upgrade.service` si
  ça suffit à les sérialiser, sinon il le documente.
- Healthchecks : comme restic,
  ```nix
  systemd.services.nixos-upgrade = {
    wants = [ "healthchecks@nixos-upgrade:start.service" ];
    onSuccess = [ "healthchecks@nixos-upgrade:success.service" ];
    onFailure = [ "healthchecks@nixos-upgrade:failure.service" ];
  };
  ```
  Le check est créé à la volée par `start?create=1`. L'utilisateur règle ensuite sa
  période (1 jour) et sa grâce dans l'UI healthchecks : étape manuelle à signaler. En cas de
  reboot, la machine redémarre avant que `onSuccess` ne parte : le builder vérifie dans le
  module si le reboot a lieu dans le script de l'unité. Si c'est le cas, le ping success
  n'arrive jamais les nuits de reboot. Dans ce cas, envoyer le ping avant le reboot, ou
  accepter que le check passe en retard puis se rétablisse au run suivant, et le documenter.

Conséquence à documenter dans `CLAUDE.md` : tout ce qui est poussé sur `main` part en prod
dans la nuit. `mise run srv-1` reste le moyen de tester une branche, mais l'auto-upgrade
suivant remet `main`.

## Livraison

Deux PR sur GitHub (`main`) : d'abord le ménage, puis l'automatisation (parties 2 et 3).
Le workflow ne peut être testé qu'une fois sur `main` : GitHub ne propose `workflow_dispatch`
que pour les workflows présents sur la branche par défaut. Le builder le déclenche une fois et vérifie que la PR créée a le diff dix attendu.
L'auto-upgrade se valide sur srv-1 avec `systemctl start nixos-upgrade` puis
`systemctl list-timers nixos-upgrade`, une fois la PR 2 mergée et déployée. Le déploiement
reste fait par l'utilisateur, ou demandé explicitement.

## Laissé au builder

Choix de l'action d'installation de Nix, épinglage des versions d'actions, formatage exact du
corps de PR, nom du fichier de l'auto-upgrade, et la vérification des trois comportements du
module `system.autoUpgrade` cités plus haut (`--refresh`, condition de reboot, reboot dans
l'unité ou non).
