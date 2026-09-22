# Odoo sur srv-1

Date : 2026-09-22
Statut : déployé, base PostgreSQL **locale**. La tentative avec la base chez OVH a été
mesurée puis abandonnée — voir « Pourquoi la base n'est pas chez OVH ».

## Problème

Évaluer Odoo pour une petite structure (~5 utilisateurs) sur srv-1, avec une
configuration qu'on garde si Odoo convainc : vhost Caddy interne, version pinnée par
nixpkgs.

L'intention de départ était de mettre la base sur l'instance OVH Web Cloud Databases
`ag56382-001`, là où vivent déjà `miniflux`, `paperless`, `wallabag` et `mealie`. C'est ce
qui a été construit, déployé, puis mesuré et défait. La section suivante dit pourquoi ;
elle est le cœur de ce document.

## Pourquoi la base n'est pas chez OVH

Odoo émet des centaines de requêtes SQL par page, largement sérialisées. La latence par
requête est donc multipliée, pas amortie.

Mesure directe depuis srv-1, `psql` sur la base OVH :

```
SELECT 1;  →  10,066 ms / 9,782 ms / 9,736 ms
```

Une latence fixe, pas de la gigue. Mesure indirecte, par les lignes werkzeug d'Odoo (dont
les trois derniers champs sont requêtes / temps base / temps hors base) :

| Requête | Requêtes | Temps base | Par requête |
|---|---|---|---|
| `GET /odoo/apps` | 71 | 0,803 s | 11,3 ms |
| `get_views` | 46 | 0,513 s | 11,2 ms |
| `search_panel_select_range` | 39 | 0,429 s | 11,0 ms |
| `web_read` | 15 | 0,191 s | 12,7 ms |
| `load_menus` | 13 | 0,162 s | 12,5 ms |
| installation du module `mail` | 5068 | 60,44 s | 11,9 ms |

Du plus petit appel au chargement de cinq mille requêtes, tout converge sur 11–12 ms.
**Le « temps base » d'Odoo était de la latence réseau à l'état pur** : la base OVH ne
travaillait presque pas. Afficher la simple liste des applications coûtait 0,8 s
d'attente ; une liste de factures, à 200–400 requêtes, en aurait coûté 2,5 à 5.

La cause est structurelle et aucun réglage ne la corrige : srv-1 est un dédié OVH, mais
`ag56382-001` vit sur l'infrastructure d'hébergement mutualisé — autre réseau, autre
datacentre.

Le symptôme le plus net est arrivé à l'installation de la Facturation depuis l'interface :
48 modules à installer, `limit_time_real` à 120 s, et l'installation tourne dans un worker
HTTP. Elle a été tuée au module 28, laissant 21 modules en état `to install` et la base
inutilisable. Avec une base locale, ces 48 modules s'installent en une trentaine de
secondes.

## Architecture

```
navigateur (Tailscale)
      │
      ▼
Caddy  odoo.srv-1.augendre.info   (import internal → bind Tailscale + filtre client_ip)
      ├─ /websocket ──► localhost:8072   (longpolling, requis par Discuss)
      └─ /         ──► localhost:8069
                              │
                        odoo.service        (User=odoo)
                     ODOO_RC = INI du store
                              │
                    ┌─────────┴──────────┐
                    ▼                    ▼
        /var/lib/private/odoo/data   socket unix locale, auth peer
        (filestore)                  PostgreSQL 17, base « odoo »
```

Plus de secret, plus de mot de passe : l'utilisateur système `odoo` correspond au rôle
`odoo` que le module crée, et l'authentification `peer` sur la socket unix fait le reste.

## Les pièges rencontrés

Aucun n'a été deviné, tous ont coûté un aller-retour.

### `odoo19` exige une exception `permittedInsecurePackages`

`pkgs.odoo19` tire `python3.12-pypdf2-3.0.1`, marqué de six CVE (CVE-2026-27024, -27025,
-27628, -27888, -28351, -33699). PyPDF2 est le fork abandonné de pypdf : aucun correctif
amont n'est possible.

Décision assumée : on reste sur `odoo19` et on pose
`nixpkgs.config.permittedInsecurePackages = [ "python3.12-pypdf2-3.0.1" ]`, épinglé à la
version exacte pour que l'exception échoue le jour où elle n'est plus nécessaire, plutôt
que de traîner.

Deux alternatives étudiées et écartées : `pkgs.odoo18`, qui substitue déjà `pypdf` via
`pythonRemoveDeps` mais démarre une version majeure en retard ; et transposer cette
substitution à `odoo19`, vérifiée comme évaluable et donnant une clôture propre, mais
nixpkgs fournit pypdf 6.15.0 là où Odoo 19 déclare `pypdf==5.4.0` — on échangeait une CVE
connue contre un risque fonctionnel non mesuré.

Condition de sortie : le `requirements.txt` d'Odoo 19 bascule sur `pypdf` dès Python 3.13,
et sa couche d'adaptation (`odoo/tools/pdf/`, essayée dans l'ordre `_pypdf2_2`, `_pypdf`,
`_pypdf2_1`) le gère déjà. L'exception saute d'elle-même quand nixpkgs construira `odoo19`
avec python313.

### Surtout pas de `dbfilter`

Ajouter `dbfilter = "^odoo$"` ressemble à un durcissement. C'en est le contraire, et ça
casse l'application entièrement : toutes les pages répondent *The database manager has
been disabled by the administrator*.

`odoo/service/db.py` :

```python
def list_dbs(force=False):
    if not config['dbfilter'] and config['db_name']:
        # ... use the value of --database as comma separated list of exposed databases
        return sorted(config['db_name'])
    ...
    db = odoo.sql_db.db_connect('postgres')   # énumère pg_database
```

Le raccourci « `db_name` est la liste des bases exposées » n'est pris **que si `dbfilter`
est vide**. Sinon Odoo se connecte à la base de maintenance `postgres` pour lister
`pg_database` — ce qu'un hébergement mutualisé refuse. `db_name` seul restreint déjà à une
base (`type='comma'`, donc une liste), sans rien énumérer.

### Odoo 19 écoute sur `0.0.0.0` par défaut

```
WARNING odoo.tools.config: missing --http-interface/http_interface, using 0.0.0.0
by default, will change to 127.0.0.1 in 20.0
```

Sans `http_interface = "127.0.0.1"`, Odoo écoute sur toutes les interfaces de srv-1, y
compris l'IP publique. Le `bind` du snippet Caddy `(internal)` et son filtre `client_ip`
seraient contournés en tapant `srv-1:8069`. C'est le seul réglage de ce document dont
l'oubli est une faille et pas une gêne.

### Le module impose un PostgreSQL local — ce qui tombe bien maintenant

`services.odoo` pose en dur `services.postgresql.enable = true`, `ensureDatabases`,
`ensureUsers` et un `requires = [ "postgresql.target" ]`. Le pointer ailleurs demandait
trois `mkForce`, plus un `services.postgresql.package` explicite : l'unité lit cette
option dans son `path` pour le `pg_dump` de la sauvegarde intégrée d'Odoo, et l'option
perd toute valeur quand le service est désactivé.

Avec la base locale, tout ce bricolage disparaît. On garde seulement
`services.postgresql.package = pkgs.postgresql_17` explicite, pour la même raison qu'on
épingle `odoo19` : le défaut suit le `stateVersion`, et changer de version majeure de
PostgreSQL ne se fait pas par un rebuild — il faut passer `pg_upgrade` sur le répertoire
de données.

### `limit_time_real` ne se règle pas « pour compenser la latence »

La valeur 120 est **le défaut d'Odoo** (`my_default=120` dans `tools/config.py`). L'écrire
dans la configuration en croyant accommoder une base distante ne change rien. Et comme
l'installation de modules depuis l'interface passe par un worker HTTP, c'est cette limite
qui tue les installations longues. Avec la base locale, le défaut suffit.

## Le module

`hosts/srv-1/services/odoo.nix`, un seul fichier, plus son import dans
`hosts/srv-1/services/default.nix`. Le vhost Caddy y vit aussi, comme pour
`stirling-pdf.nix`, `paperless.nix` et `miniflux.nix` : ce qui change ensemble vit
ensemble.

Les deux routes Caddy sont dans des blocs `handle`, qui sont mutuellement exclusifs.
Mélanger un `handle` et un `reverse_proxy` nu ferait dépendre le résultat de l'ordre des
directives Caddy, qui n'est pas celui du fichier — et Discuss casserait silencieusement.

## Bruit connu

Chaque processus Odoo émet au démarrage un `DeprecationWarning: PyPDF2 is deprecated`
suivi d'une trace de vingt lignes, soit environ 120 lignes de journal par redémarrage.
C'est le coût cosmétique du choix `odoo19` : `odoo/tools/pdf/` importe `PyPDF2.filters`
avant de choisir son implémentation. Inoffensif, mais il faut le savoir avant de croire à
une erreur en lisant `journalctl`.

## Hors périmètre

- **Les sauvegardes.** Rien ne sauvegarde la base pour l'instant, et c'est le point le
  plus important de cette liste : en passant en local, la responsabilité est revenue sur
  srv-1 et OVH ne fait plus de dump automatique. `services.postgresqlBackup` (`enable`,
  `databases = [ "odoo" ]`, `startAt`) écrit dans `/var/backup/postgresql`, qu'il suffit
  d'ajouter aux `paths` de `restic.nix` — plus `"odoo.service"` dans ses `servicesToStop`
  pour que base et filestore atterrissent dans le même instantané. Le filestore seul est
  **déjà** couvert : `/var/lib/private` est dans les chemins.
- Addons personnalisés (`services.odoo.addons`).
- Exposition publique.
- Check healthchecks.
- Montée de version Odoo (de `odoo19` à `odoo20` : il faut jouer les migrations).

Le nom `odoo.srv-1.augendre.info` est temporaire, sur le modèle de
`pdf.srv-1.augendre.info`. Un passage en adopté justifiera un nom sans `srv-1`.
