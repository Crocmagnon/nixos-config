# SSO Authelia (étape 1) — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Une seule connexion (passkey) pour Readeck, Miniflux, Calibre-web et Stirling-PDF, via
Authelia sur srv-1, entièrement déclarée dans ce repo et réversible.

**Architecture:** Authelia (`services.authelia.instances.main`) sert le portail et le
fournisseur OIDC sur `auth.srv-1.augendre.info`, derrière Caddy en `import internal`. Readeck et
Miniflux sont des clients OIDC ; Calibre-web et Stirling passent par un snippet Caddy `(sso)`
(`forward_auth`), Calibre-web lisant `Remote-User`.

**Tech Stack:** NixOS 26.05, Authelia 4.39.20, Caddy 2.11.7, agenix, Readeck 0.23.5 (unstable),
Miniflux 2.3.5, Calibre-web 0.6.26.

**Spec:** `docs/superpowers/specs/2026-11-24-sso-authelia-design.md`

## Global Constraints

- Hôte du portail : `auth.srv-1.augendre.info` ; cookie de session : domaine `srv-1.augendre.info`.
- Utilisateur Authelia : `gaugendre`, email `gabriel@augendre.info`, groupe `admins`.
- `default_policy: deny` ; vhosts du portail et clients OIDC : `one_factor` pour `group:admins`.
- Authelia écoute sur `127.0.0.1:9092` (9091 est pris par le RPC de Transmission).
- Aucun hash de mot de passe ni secret en clair dans le repo ; les digests pbkdf2 des secrets
  clients OIDC, si.
- Claude ne lance ni `age` ni `agenix` et ne lit pas les `*.age` (`.claude/settings.json`) :
  toute création ou édition de secret est une étape **de l'utilisateur**.
- Les comptes locaux des apps ne sont jamais supprimés ni rendus inutilisables.
- Les services protégés par en-tête n'écoutent que sur `127.0.0.1` (déjà le cas).
- Ce qui est sur `main` part en prod la nuit (04:00–04:30). Une branche déployée par
  `mise run srv-1` est remplacée par `main` la nuit suivante.
- Messages de commit : préfixe `srv-1: `, en anglais comme l'historique ; commentaires Nix en
  français comme les fichiers voisins.
- Vérification de build : `nix build .#nixosConfigurations.srv-1.config.system.build.toplevel`
  (la CI `pr-build` fait le même build sur la PR).

## Review Focus

1. Un client du tailnet qui envoie lui-même `Remote-User: gaugendre` : refusé partout, y compris
   sur `books.srv-1…/opds` qui n'a pas de `forward_auth` (test : Task 3, étape 4).
2. KOReader en OPDS sur Calibre-web : doit marcher sans portail, avec l'auth Basic de
   Calibre-web, malgré `reverseProxyAuth` actif (test : Task 3, étape 4).
3. Première connexion OIDC sur Readeck : rattache le compte existant **et** le garde admin
   (test : Task 4, étape 4).
4. Retour à `main` la nuit avec Readeck redescendu en 0.22 après les migrations 0.23 : empêché
   en livrant le passage en unstable seul et d'abord sur `main` (Task 0).
5. Plugin KOReader Miniflux (clé d'API, `X-Auth-Token`) après `DISABLE_LOCAL_AUTH` : doit
   continuer à marcher (test : Task 6, étape 3).

---

### Task 0: Readeck depuis nixpkgs-unstable (PR à part, mergée d'abord)

**Files:**
- Modify: `overlays/unstable-packages.nix` (liste `inherit (unstable)`)

**Interfaces:**
- Produces: `pkgs.readeck` en ≥ 0.23.4, dont dépend la Task 4.

- [ ] **Step 1:** Ajouter `readeck` à `inherit (unstable)` (ordre de la liste existante).
- [ ] **Step 2:** `nix eval --raw .#nixosConfigurations.srv-1.pkgs.readeck.version` → `0.23.5` ou plus.
- [ ] **Step 3:** Build de srv-1 (commande des Global Constraints) → succès.
- [ ] **Step 4:** Commit `srv-1: readeck from unstable (0.23, OIDC)` sur une branche partant de
  `origin/main` (pas `sso-authelia`), PR, merge par l'utilisateur. Rebaser ensuite
  `sso-authelia` sur `main`.

### Task 1: Secrets Authelia (étape utilisateur, guidée)

**Files:**
- Modify: `hosts/srv-1/age/agenix-rules.nix`, `hosts/srv-1/age/default.nix`
- Create (utilisateur, via agenix) : `hosts/srv-1/age/authelia-{jwt,storage-key,oidc-hmac,oidc-jwk,users}.age`
- Modify (utilisateur) : `readeck-env.age`, `miniflux-db.age`

**Interfaces:**
- Produces: `config.age.secrets."authelia-<nom>".path` pour les 5 secrets, propriétaire
  `authelia-main` ; digests pbkdf2 des clients `readeck` et `miniflux` (non secrets, collés dans
  la Task 2) ; `READECK_AUTH_OIDC_PROVIDERS_0_CLIENT_SECRET` dans `readeck-env` ;
  `OAUTH2_CLIENT_SECRET` dans `miniflux-db`.

- [ ] **Step 1 (Claude):** Ajouter les 5 règles dans `agenix-rules.nix` (`allUsers ++ [ systems.srv-1 ]`)
  et `owner = "authelia-main"` pour chacune dans `default.nix`. Commit
  `srv-1: agenix rules for authelia`.
- [ ] **Step 2 (utilisateur):** Générer et chiffrer, depuis `hosts/srv-1/age`, en fish
  (`nix shell nixpkgs#authelia` pour la CLI) :
  - `authelia-jwt`, `authelia-storage-key`, `authelia-oidc-hmac` :
    `authelia crypto rand --length 64 --charset alphanumeric`, une valeur chacun.
  - `authelia-oidc-jwk` : `authelia crypto pair rsa generate --bits 4096 --directory <dossier tmpfs>`,
    contenu de `private.pem`.
  - `authelia-users` : `users_database.yml` avec `users.gaugendre` (`displayname`,
    `email: gabriel@augendre.info`, `groups: [admins]`, `password` =
    `authelia crypto hash generate argon2`).
  - Pour `readeck` et `miniflux` :
    `authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986`.
    Le *Random Password* va dans `readeck-env`
    (`READECK_AUTH_OIDC_PROVIDERS_0_CLIENT_SECRET=…`) et `miniflux-db`
    (`OAUTH2_CLIENT_SECRET=…`) ; le *Digest* est donné à Claude.
  - Astuce pour éviter le copier-coller dans l'éditeur : `env EDITOR="cp <fichier>" agenix -e <nom>.age`.
- [ ] **Step 3 (Claude):** `git status` : les 5 `.age` existent ; commit
  `srv-1: authelia secrets` (fichiers chiffrés seulement).

### Task 2: Authelia, snippet `(sso)` et Stirling derrière le portail

**Files:**
- Create: `hosts/srv-1/services/authelia.nix`
- Modify: `hosts/srv-1/services/default.nix`, `hosts/srv-1/services/caddy.nix` (snippet à côté de
  `(internal)`), `hosts/srv-1/services/stirling-pdf.nix`, `hosts/srv-1/services/restic.nix` (`paths`)

**Interfaces:**
- Consumes: secrets et digests de la Task 1.
- Produces: snippet Caddy `(sso)` (retire `Remote-User`, `Remote-Groups`, `Remote-Email`,
  `Remote-Name` de la requête, puis `forward_auth 127.0.0.1:9092`, `uri /api/authz/forward-auth`,
  `copy_headers` de ces 4 en-têtes) ; issuer OIDC `https://auth.srv-1.augendre.info` ; clients
  `readeck` et `miniflux` ; politique `admins_one_factor`.

- [ ] **Step 1: `authelia.nix`** — en tête, le commentaire de procédure de retrait (section
  « Réversibilité » de la spec, étapes 1 à 5). Puis l'instance `main` :
  - `secrets.{jwtSecretFile,storageEncryptionKeyFile,oidcHmacSecretFile,oidcIssuerPrivateKeyFile}`.
  - `settings` : `server.address = "tcp://127.0.0.1:9092/"` ; `authentication_backend.file.path`
    = secret `authelia-users`, `password_reset.disable` et `password_change.disable` à `true` ;
    `session.cookies = [{ domain = "srv-1.augendre.info"; authelia_url =
    "https://auth.srv-1.augendre.info"; remember_me = "1M"; }]` ; `storage.local.path =
    "/var/lib/authelia-main/db.sqlite3"` ; `notifier.filesystem.filename =
    "/var/lib/authelia-main/notification.txt"` ; `webauthn` avec connexion par passkey
    (`enable_passkey_login`, vérifier le nom de clé dans le schéma 4.39) ;
    `access_control.default_policy = "deny"` + règle `one_factor`, `subject = "group:admins"`,
    domaines `pdf.srv-1.augendre.info` et `books.srv-1.augendre.info`.
  - `identity_providers.oidc` : `authorization_policies.admins_one_factor` (défaut `deny`,
    règle `one_factor` pour `group:admins`) ; clients :
    - `readeck` : redirect `https://readeck.augendre.info/login/oidc`, scopes
      `openid email profile groups`, `require_pkce = true`, `pkce_challenge_method = "S256"`.
    - `miniflux` : redirect `https://reader.augendre.info/oauth2/oidc/callback`, scopes
      `openid email profile`.
    - les deux : `client_secret` = digest de la Task 1, `authorization_policy =
      "admins_one_factor"`, `token_endpoint_auth_method = "client_secret_basic"` (passer à
      `client_secret_post` si les logs d'Authelia le demandent).
  - Vhost `auth.srv-1.augendre.info` : `import common_headers`, `import internal`,
    `reverse_proxy 127.0.0.1:9092`.
- [ ] **Step 2:** Snippet `(sso)` dans `caddy.nix` (commentaire d'une ligne : pourquoi on retire
  les en-têtes avant `forward_auth`). Stirling : `import sso` après `import internal`. Restic :
  `"/var/lib/authelia-main"` dans `paths`.
- [ ] **Step 3:** Build de srv-1 → succès. Commit `srv-1: authelia, sso snippet, stirling behind it`.
- [ ] **Step 4:** Avec l'accord de l'utilisateur : push de la branche, `mise run srv-1`.
  Puis, depuis le desktop (tailnet) :
  - `curl -s https://auth.srv-1.augendre.info/.well-known/openid-configuration | jq -r .issuer`
    → `https://auth.srv-1.augendre.info`
  - `curl -sI https://pdf.srv-1.augendre.info/ | grep -i '^location'` → redirection vers
    `https://auth.srv-1.augendre.info/?rd=…`
  - `ssh srv-1 systemctl is-active authelia-main` → `active`
- [ ] **Step 5 (utilisateur):** Connexion par mot de passe sur `auth.srv-1.augendre.info`,
  enregistrement d'une passkey (code : `ssh srv-1 sudo cat /var/lib/authelia-main/notification.txt`),
  déconnexion, reconnexion par passkey seule, puis Stirling s'ouvre sans rien demander.

### Task 3: Calibre-web par en-tête, `/opds` hors portail

**Files:**
- Modify: `hosts/srv-1/services/calibre-web.nix`

**Interfaces:**
- Consumes: snippet `(sso)` (Task 2).

- [ ] **Step 1:** Vérifier que le username Calibre-web est `gaugendre` :
  `ssh srv-1 sudo sqlite3 /var/lib/calibre-web/app.db 'select name from user'`. Sinon, s'arrêter
  et demander à l'utilisateur lequel renommer.
- [ ] **Step 2:** `options.reverseProxyAuth = { enable = true; header = "Remote-User"; }`. Vhost :
  `import common_headers`, `import internal`, retrait de `Remote-User` (et des 3 autres) pour tout
  le vhost, puis `handle` pour `/opds` et `/opds/*` sans portail, et `handle` pour le reste avec
  `import sso` ; les deux font `reverse_proxy` vers le port actuel.
- [ ] **Step 3:** Build → succès. Commit `srv-1: calibre-web behind sso, opds left out`. Déploiement.
- [ ] **Step 4:** Depuis le desktop :
  - `curl -s -o /dev/null -w '%{http_code}\n' -H 'Remote-User: gaugendre' https://books.srv-1.augendre.info/opds`
    → `401` (Calibre-web demande l'auth Basic, l'en-tête forgé n'a pas suffi)
  - même requête avec `-u gaugendre:<mot de passe Calibre-web>` à la place de l'en-tête → `200`
  - `curl -sI -H 'Remote-User: gaugendre' https://books.srv-1.augendre.info/ | grep -i '^location'`
    → redirection vers le portail
  - Utilisateur : navigateur connecté à Authelia → Calibre-web ouvert sans login ; KOReader
    parcourt toujours le catalogue OPDS.

### Task 4: Readeck en OIDC

**Files:**
- Modify: `hosts/srv-1/services/readeck.nix`

**Interfaces:**
- Consumes: `pkgs.readeck` ≥ 0.23.4 (Task 0) ; client `readeck` (Task 2) ;
  `READECK_AUTH_OIDC_PROVIDERS_0_CLIENT_SECRET` dans `readeck-env` (Task 1).

- [ ] **Step 1:** Utilisateur : confirmer que le compte Readeck a le username `gaugendre` ou
  l'email `gabriel@augendre.info` (sinon s'arrêter : un rattachement échouerait).
- [ ] **Step 2:** `settings.auth.oidc.providers = [{ name = "Authelia"; url =
  "https://auth.srv-1.augendre.info"; client_id = "readeck"; groups = [ [ "admins" "admin" ] ];
  provisioning = false; }]` (sans `client_secret`, qui vient de l'env à l'index 0). Commentaire
  d'une ligne sur le mapping de groupe (sans lui, le compte redevient `user`).
- [ ] **Step 3:** Build → succès. Commit `srv-1: readeck oidc login via authelia`. Déploiement ;
  `ssh srv-1 systemctl is-active readeck` → `active`.
- [ ] **Step 4 (utilisateur):** bouton « Authelia » sur l'écran de login → connecté sans
  ressaisie, sur son compte existant (articles présents), et le menu d'administration est
  toujours là. L'app mobile Readeck marche toujours.

### Task 5: Miniflux en OIDC, rattachement du compte

**Files:**
- Modify: `hosts/srv-1/services/miniflux.nix`

**Interfaces:**
- Consumes: client `miniflux` (Task 2) ; `OAUTH2_CLIENT_SECRET` dans `miniflux-db` (Task 1).

- [ ] **Step 1:** `config` : `OAUTH2_PROVIDER = "oidc"`, `OAUTH2_CLIENT_ID = "miniflux"`,
  `OAUTH2_REDIRECT_URL = "https://reader.augendre.info/oauth2/oidc/callback"`,
  `OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://auth.srv-1.augendre.info"`,
  `OAUTH2_USER_CREATION = 0`. `WEBAUTHN` reste à `1`.
- [ ] **Step 2:** Build → succès. Commit `srv-1: miniflux oidc login via authelia`. Déploiement.
- [ ] **Step 3 (utilisateur):** connecté à Miniflux par mot de passe ou passkey, Réglages →
  lier le compte OpenID Connect ; déconnexion ; bouton OIDC → connecté sur le même compte.

### Task 6: Miniflux sans login local (commit à part, après la Task 5)

**Files:**
- Modify: `hosts/srv-1/services/miniflux.nix`

- [ ] **Step 1:** `DISABLE_LOCAL_AUTH = 1`, avec un commentaire d'une ligne : à retirer **en même
  temps** que la config `OAUTH2_*` en cas de retour arrière.
- [ ] **Step 2:** Build → succès. Commit `srv-1: miniflux without local login`. Déploiement.
- [ ] **Step 3:** Vérifications :
  - `curl -s -o /dev/null -w '%{http_code}\n' -H 'X-Auth-Token: <clé API>' https://reader.augendre.info/v1/me`
    → `200` (clé fournie par l'utilisateur, ou l'utilisateur lance la commande)
  - Utilisateur : le plugin KOReader `miniflux-download` télécharge toujours les articles ;
    l'écran de login Miniflux n'a plus de formulaire de mot de passe, seulement le bouton OIDC.

### Task 7: Fin de branche

- [ ] **Step 1:** Mettre à jour `CLAUDE.md` : une puce sous « Caddy Internal Access » sur
  `import sso` (ce qu'il fait, qu'il s'ajoute à `import internal`, la piste `/opds` de
  Calibre-web comme exemple d'exclusion). Commit `docs: sso snippet in CLAUDE.md`.
- [ ] **Step 2:** PR `sso-authelia` → `main`, avec le lien vers la spec ; l'utilisateur merge
  (sinon la nuit suivante remet srv-1 sur `main`, sans Authelia).
