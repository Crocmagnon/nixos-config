# Odoo sur srv-1, base PostgreSQL chez OVH

Date : 2026-09-22
Statut : design validé, implémentation à faire

## Problème

On veut évaluer Odoo pour une petite structure (~5 utilisateurs) sur srv-1, sans monter
de PostgreSQL local : la base va rejoindre les six autres (`miniflux`, `manuels`,
`paperless`, `wallabag`, `mealie`, `lasuitemeet`) sur l'instance OVH Web Cloud Databases
`ag56382-001`, déclarée dans le dépôt `terraform-ovh`.

Le test doit produire une configuration qu'on garde si Odoo convainc : vhost Caddy
interne, secret agenix, version pinnée par nixpkgs. Pas de sauvegarde dédiée ni de
monitoring pour l'instant — c'est ce qu'on ajoutera au passage en « adopté ».

## Contraintes découvertes

### Le module nixpkgs impose un PostgreSQL local

`services.odoo` existe (`nixos/modules/services/finance/odoo.nix`) et fournit
`pkgs.odoo19` par défaut puisque `system.stateVersion = "25.11"`. Mais il pose en dur,
sans condition :

```nix
services.postgresql = {
  enable = true;
  ensureDatabases = [ "odoo" ];
  ensureUsers = [ { name = "odoo"; ensureDBOwnership = true; } ];
};
systemd.services.odoo.requires = [ "postgresql.target" ];
```

Le pointer vers une base distante demande donc de désarmer les trois : `enable`,
`requires` et le `after` correspondant. C'est le seul coût du module, et il est payé une
fois.

On garde en revanche son `path = [ config.services.postgresql.package ]` : il fournit
`pg_dump`, dont Odoo se sert pour sa fonction de sauvegarde intégrée.

### L'offre OVH n'est pas un PostgreSQL administrable

- Pas de superuser, pas de `CREATEDB` : la base est créée par Terraform, jamais par
  Odoo. `list_db = false` (déjà le défaut du module) désactive le gestionnaire de bases.
- Pas de `CREATE EXTENSION` depuis le client — mais les extensions s'activent à la main
  depuis l'espace client OVH. On active donc **`unaccent`** et on pose `unaccent = true`
  dans la configuration Odoo : la recherche devient insensible aux accents, ce qui compte
  sur des données françaises (« société » trouvé en tapant « societe »).
  Odoo détecte l'extension au démarrage (`SELECT proname FROM pg_proc WHERE proname =
  'unaccent'`) et se rabat silencieusement sur une recherche accent-sensible si elle
  manque : se tromper ici dégrade, ça ne casse pas.
- Le grant `admin` du module Terraform `./modules/db` fait du user le propriétaire de la
  base : Odoo peut y créer ses tables.

### Le budget de connexions

L'instance annonce **200 connexions simultanées**. La documentation OVH ne dit pas si
c'est par serveur ou par base — et on n'a pas besoin de le savoir : on dimensionne pour
que la réponse soit sans effet.

Odoo ouvre un pool par processus, plafonné à `db_maxconn` :

| Processus | Nombre |
|---|---|
| workers HTTP (`workers`) | 3 |
| threads cron (`max_cron_threads`, défaut) | 2 |
| processus longpolling / gevent | 1 |

Soit 6 processus × `db_maxconn = 4` = **24 connexions au pire**, et moins en pratique
puisque le pool s'ouvre paresseusement. Confortable dans les 200, même partagées avec
les six autres bases.

### Version PostgreSQL

L'instance tourne en **PostgreSQL 17**. Odoo 19 exige ≥ 12 ; 17 est dans la fenêtre. À
reconfirmer au premier démarrage, c'est gratuit.

### La latence

Odoo est nettement plus bavard avec sa base que tout ce qui tourne déjà sur srv-1 —
plusieurs centaines de requêtes par page. srv-1 est un dédié OVH et la clouddb est chez
OVH : la latence devrait être faible, et paperless/miniflux/wallabag/mealie valident déjà
le chemin. C'est malgré tout le risque principal de l'architecture, et il ne se mesure
qu'en essayant. `limit_time_real = 120` évite qu'un worker se fasse tuer pendant qu'on
mesure.

### Le mot de passe ne peut pas passer par la configuration

`services.odoo.settings` génère un INI dans le store, lisible par tous, dans un dépôt
public. Odoo n'offre aucune variable d'environnement pour `db_password`.

La sortie : laisser `db_password` vide et compter sur libpq. psycopg2 retombe sur les
défauts libpq quand le paramètre est absent, donc `PGPASSWORD` depuis un `EnvironmentFile`
agenix suffit. **C'est une hypothèse à vérifier avant tout le reste** (voir phase 2).

## Architecture

```
navigateur (Tailscale)
      │
      ▼
Caddy  odoo.srv-1.augendre.info   (import internal → bind Tailscale + filtre client_ip)
      ├─ /websocket ──► localhost:8072   (longpolling, requis par Discuss)
      └─ /         ──► localhost:8069
                              │
                        odoo.service
                    ODOO_RC = INI du store (pas de secret)
                    EnvironmentFile = agenix (PGPASSWORD)
                              │
                    ┌─────────┴──────────┐
                    ▼                    ▼
        /var/lib/private/odoo/data   ag56382-001.eu.clouddb.ovh.net:35458
        (filestore, pièces jointes)   base « odoo », PostgreSQL 17
        déjà couvert par restic       sauvegardes automatiques OVH
```

L'état d'Odoo est volontairement éclaté en deux : le filestore sur srv-1, les métadonnées
chez OVH. Les deux sauvegardes ne sont pas synchronisées entre elles. C'est acceptable
pour un test ; c'est précisément ce que règle le `pg_dump` planifié décrit en « Hors périmètre ».

## Découpage

### Phase 1 — la base OVH (dépôt `terraform-ovh`)

Dans `databases-psql.tf`, copie conforme des six blocs existants :

```hcl
variable "psql_odoo_password" {
  description = "odoo password"
  type        = string
  sensitive   = true
}

module "db_odoo" {
  source = "./modules/db"

  db_name      = "odoo"
  db_password  = var.psql_odoo_password
  service_name = data.ovh_hosting_privatedatabase.psql.service_name
}
```

`ovh_hosting_privatedatabase_whitelist.psql_srv_1` couvre déjà les IP de srv-1 : rien à
ajouter côté réseau.

Puis, **à la main dans l'espace client OVH**, activer l'extension `unaccent` sur la base
`odoo`. Le provider Terraform OVH n'expose pas les extensions des bases privées, donc ce
geste ne se code pas : il se documente ici.

### Phase 2 — lever les inconnues

La base existe désormais, mais aucun module Nix n'est écrit tant que ces trois points ne
sont pas tranchés. Chacun a un repli connu, donc aucun n'est bloquant — mais chacun
change le code.

| # | À vérifier | Comment | Repli si ça échoue |
|---|---|---|---|
| 1 | `PGPASSWORD` atteint bien psycopg2 | la base créée, sans rien déployer : `PGPASSWORD=… nix run nixpkgs#odoo19 -- --db_host=ag56382-001.eu.clouddb.ovh.net --db_port=35458 --db_user=odoo -d odoo --stop-after-init` depuis srv-1 | générer `/run/odoo/odoo.conf` par `envsubst` dans un `ExecStartPre`, pointer `ODOO_RC` dessus (+5 lignes) |
| 2 | Odoo 19 démarre sur PostgreSQL 17 | la même commande répond, et initialise la base | rétrograder sur `pkgs.odoo18` |
| 3 | Quel uid tourne réellement | après la phase 4 : `systemctl show odoo -p User -p DynamicUser`. Le module pose `DynamicUser = true` **et** déclare `users.users.odoo` ; systemd n'alloue dynamiquement que si l'utilisateur n'existe pas, donc `owner = "odoo"` sur le secret agenix devrait être le bon | si l'uid est bel et bien dynamique, `DynamicUser = lib.mkForce false` **et** `data_dir = "/var/lib/odoo/data"`, plus l'ajout de ce chemin aux `paths` de restic (`/var/lib/private` ne le couvrirait plus) |

L'hôte et le port sont connus : `ag56382-001.eu.clouddb.ovh.net:35458`. Les points 1 et 2
se lèvent par la même commande, avant toute écriture de module ; le point 3 est une
vérification post-déploiement, dont le repli est connu.

### Phase 3 — le secret

`hosts/srv-1/age/odoo-env.age`, une ligne dans `hosts/srv-1/age/secrets.nix`. Contenu :

```
PGPASSWORD=<le mot de passe posé en phase 1>
```

`hosts/srv-1/age/default.nix` dérive `age.secrets` de `secrets.nix` par `mapAttrs'` :
aucune autre édition. L'`owner` dépend du résultat de la vérification 3 de la phase 2.

### Phase 4 — le module

Un seul fichier, `hosts/srv-1/services/odoo.nix`, plus son import dans
`hosts/srv-1/services/default.nix`.

```nix
{ config, lib, ... }:
{
  services.caddy.virtualHosts."odoo.srv-1.augendre.info".extraConfig = ''
    import common_headers
    import internal
    handle /websocket {
      reverse_proxy localhost:8072
    }
    handle {
      reverse_proxy localhost:8069
    }
  '';

  services.odoo = {
    enable = true;
    # domain reste null : Caddy fait le reverse proxy, on ne veut pas que le module
    # allume nginx.
    settings.options = {
      db_host = "ag56382-001.eu.clouddb.ovh.net";
      db_port = 35458;
      db_name = "odoo";
      db_user = "odoo";
      db_sslmode = "require";
      dbfilter = "^odoo$";
      unaccent = true; # extension activée à la main dans l'espace client OVH
      db_maxconn = 4; # 6 processus × 4 = 24 connexions au pire, cf. design
      workers = 3;
      limit_time_real = 120; # la base est distante, les requêtes traînent
      proxy_mode = true;
      # list_db = false est déjà le défaut du module
    };
  };

  # Le module allume un PostgreSQL local dont on n'a pas l'usage : la base est chez OVH.
  services.postgresql.enable = lib.mkForce false;
  systemd.services.odoo = {
    requires = lib.mkForce [ ]; # pointait sur postgresql.target, qui n'existe plus
    after = lib.mkForce [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig.EnvironmentFile = config.age.secrets."odoo-env".path;
  };
}
```

Le `handle /websocket` sépare le port longpolling du port HTTP. Sans lui, Discuss et les
notifications temps réel ne fonctionnent pas dès que `workers > 0`. Les deux routes sont
dans des blocs `handle`, qui sont mutuellement exclusifs : mélanger un `handle` et un
`reverse_proxy` nu ferait dépendre le résultat de l'ordre des directives Caddy, qui n'est
pas celui du fichier.

### Phase 5 — initialisation, une fois, à la main

La base créée en phase 1 est vide.

On **n'active pas** `services.odoo.autoInit` : il passe `--init=INIT --database=odoo
--db_user=odoo` en dur, où `INIT` n'est pas un module Odoo existant. Le comportement ne
tient qu'au fait qu'Odoo logue un module inconnu et continue. Trop fragile pour une base
de comptabilité.

À la place, sur srv-1 :

```
systemctl stop odoo
sudo -u odoo env ODOO_RC=<le fichier pointé par l'unité> \
  odoo -d odoo -i base --stop-after-init --without-demo=all
systemctl start odoo
```

Les applications s'installent ensuite depuis l'interface.

### Phase 6 — vérification

- `systemctl status odoo` vert, et les logs ne montrent ni erreur de connexion ni
  avertissement de collation bloquant.
- `https://odoo.srv-1.augendre.info` répond depuis Tailscale, et **ne répond pas** depuis
  l'extérieur (le `import internal` fait les deux : `bind` sur l'IP Tailscale et filtre
  `client_ip`).
- Discuss reçoit un message en temps réel sans rechargement — c'est le test qui prouve
  que la route `/websocket` marche.
- Une page un peu lourde (liste de factures) se charge en un temps acceptable : c'est la
  mesure de latence qui valide ou invalide l'architecture.

## Hors périmètre

Assumé, à ajouter si Odoo passe de « testé » à « adopté » :

- **Dump de la base dans restic.** On s'en remet aux sauvegardes automatiques d'OVH pour
  l'instant. Le jour venu : un timer dans `odoo.nix` qui écrit
  `pg_dump -Fc` vers `/var/lib/private/odoo/odoo.dump` à 01:30, sur le modèle de
  l'`exporter` de paperless, plus `"odoo.service"` dans `servicesToStop` de `restic.nix`.
  Restic passe à 02:00 et ramasse base et filestore dans le même instantané. Le filestore
  seul est **déjà** couvert : `/var/lib/private` est dans les chemins sauvegardés.
- Addons personnalisés (`services.odoo.addons`).
- Exposition publique.
- Check healthchecks.
- Mises à jour suivies / montée de version Odoo.

Le nom `odoo.srv-1.augendre.info` est temporaire, cohérent avec `pdf.srv-1.augendre.info`.
Un passage en adopté justifiera un nom sans `srv-1`.
