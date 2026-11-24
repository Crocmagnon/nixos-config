# SSO Authelia étape 3 (Paperless, Claire) — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Paperless en OIDC via Authelia pour l'utilisateur et Claire, Claire limitée à Paperless.

**Architecture:** client OIDC `paperless` dans `authelia.nix`, provider allauth `openid_connect` dans
Paperless (JSON dans `paperless-env`), utilisatrice `claire` dans `authelia-users.age`.

**Tech Stack:** NixOS 26.05, Authelia 4.39.20, paperless-ngx 2.20.15, django-allauth 65.16.1, Caddy 2.11.

**Spec:** `docs/superpowers/specs/2026-11-24-sso-paperless-design.md`

## Global Constraints

- Branche `sso-paperless`, worktree `~/Projects/github.com/Crocmagnon/nixos-config-paperless`,
  déploiement continu depuis la branche (`nixos-rebuild switch --refresh --flake …?ref=sso-paperless#srv-1`).
- Claude ne lance ni age ni agenix : `authelia-users.age` et `paperless-env.age` sont édités par
  l'utilisateur.
- `provider_id` allauth : `authelia` → callback `https://paperless.augendre.info/accounts/oidc/authelia/login/callback/`.
- Groupes Authelia : `admins` (l'utilisateur), `famille` (Claire).
- Vérification de build : `nix build .#nixosConfigurations.srv-1.config.system.build.toplevel`.

## Review Focus

1. Claire connectée à Authelia ouvre Sonarr / Readeck / Miniflux / Calibre-web : refusée partout
   (test : Task 2, étape 4).
2. Première connexion OIDC sur Paperless non rattachée : erreur, pas de compte neuf (Task 2, étape 3).
3. App mobile après désactivation du login web (Task 3, étape 3).
4. `/admin/` encore utilisable avec la session OIDC, `/admin/login/` refusé (Task 3, étape 3).
5. Transmission après passage à `{env.…}` : toujours authentifié par Caddy (Task 4, étape 2).

---

### Task 1: Secrets (utilisateur, guidé)

- [ ] **Step 1 (Claude):** générer le digest du client `paperless` en donnant à l'utilisateur la
  commande pbkdf2 (comme l'étape 1) ; le digest va dans `authelia.nix`, le secret en clair dans
  `paperless-env` sous la forme
  `PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect":{"APPS":[{"provider_id":"authelia","name":"Authelia","client_id":"paperless","secret":"<secret>","settings":{"server_url":"https://auth.srv-1.augendre.info","token_auth_method":"client_secret_basic"}}]}}`.
- [ ] **Step 2 (utilisateur):** ajouter `claire` à `authelia-users.age` (`displayname: "Claire"`,
  `email: claire@coccomagnard.fr`, `groups: [famille]`, hash argon2 d'un mot de passe initial).

### Task 2: Authelia + Paperless OIDC (login par mot de passe encore actif)

**Files:** `hosts/srv-1/services/authelia.nix`, `hosts/srv-1/services/paperless.nix`

- [ ] **Step 1:** `authelia.nix` : politique OIDC `paperless` (défaut `deny`, `one_factor` pour
  `group:admins` et `group:famille`) ; client `paperless` (redirect ci-dessus, scopes
  `openid email profile`, `consent_mode = "implicit"`, `client_secret_basic`, digest Task 1).
  Procédure de retrait : ajouter Paperless et Claire.
- [ ] **Step 2:** `paperless.nix` : `PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect"`,
  `PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = false`, commentaire sur la forme du JSON dans
  `paperless-env` ; `TODO(26.11)` : l'OIDC est concerné, `token_auth_method` déjà posé.
  Build, commit, push, déploiement.
- [ ] **Step 3:** vérifs :
  - `curl -s https://paperless.augendre.info/accounts/login/ | grep -c 'oidc/authelia'` → ≥ 1
  - `ssh srv-1 systemctl is-active paperless-web authelia-main` → `active` ×2
  - utilisateur : se connecte par mot de passe, « Mon profil » → connecter Authelia → déconnexion →
    bouton Authelia → même compte.
- [ ] **Step 4 (utilisateur + Claire):** Claire se connecte à Authelia (mot de passe initial),
  enregistre sa passkey (code : `ssh srv-1 sudo cat /var/lib/authelia-main/notification.txt`),
  rattache son compte Paperless, et constate qu'`https://sonarr.srv-1.augendre.info` lui est refusé.
  Test de l'app mobile en OIDC (sinon jeton d'API).

### Task 3: Login web désactivé, `/admin/login/` bloqué (après la Task 2, étape 4)

**Files:** `hosts/srv-1/services/paperless.nix`

- [ ] **Step 1:** `PAPERLESS_DISABLE_REGULAR_LOGIN = true`, `PAPERLESS_REDIRECT_LOGIN_TO_SSO = true` ;
  vhost : `respond /admin/login/* 403` (commentaire : l'admin reste accessible avec la session OIDC).
- [ ] **Step 2:** build, commit, déploiement.
- [ ] **Step 3:** vérifs :
  - `curl -s -o /dev/null -w '%{http_code}' https://paperless.augendre.info/admin/login/` → `403`
  - `curl -s -o /dev/null -w '%{http_code}' -u x:y https://paperless.augendre.info/api/` → `401`
    (l'API répond toujours, auth refusée pour de faux identifiants)
  - utilisateur : `/` redirige vers Authelia ; `/admin/` s'ouvre une fois connecté ; app mobile OK.

### Task 4: Remarques mineures

**Files:** `hosts/srv-1/services/{authelia,caddy,readeck,servarr}.nix`

- [ ] **Step 1:** snippet `(sso)` déplacé dans `authelia.nix` (`services.caddy.extraConfig`, port en
  variable) ; `adminsOneFactor` inliné s'il ne sert qu'une fois ; commentaire `readeck.nix`
  (username/email réécrits) ; `{$TRANSMISSION_BASIC_AUTH}` → `{env.TRANSMISSION_BASIC_AUTH}`.
- [ ] **Step 2:** build, déploiement ; vérifs : `pdf.srv-1…` → 302 vers le portail ;
  `curl -s localhost:2019/config/ | grep -oE '"Basic [^"]*"'` sur srv-1 →
  `"Basic {env.TRANSMISSION_BASIC_AUTH}"` (le placeholder, pas la valeur) ;
  utilisateur : Transmission s'ouvre sans mot de passe.
- [ ] **Step 3:** PR, merge par l'utilisateur.
