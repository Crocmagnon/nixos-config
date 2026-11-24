# SSO Authelia — étape 3 : Paperless et le compte de Claire

Suite de `2026-11-24-sso-authelia-design.md` (étape 1 : Readeck, Miniflux, Calibre-web, Stirling ;
étape 2 : \*arr, Transmission). Petite extension : mêmes choix, mêmes contraintes.

## Intention

Paperless est utilisé par l'utilisateur et par Claire, sur le web et via une app mobile. Tous deux
se connectent à Paperless par Authelia (passkey), sans formulaire de mot de passe sur le web.
Claire n'a accès qu'à Paperless.

## Objectifs

1. Paperless en OIDC natif (allauth), fournisseur Authelia.
2. Un utilisateur Authelia `claire` (email `claire@coccomagnard.fr`), groupe `famille`, autorisé sur
   Paperless seulement.
3. Comptes Paperless existants rattachés, pas recréés : `gabriel@augendre.info`,
   `claire@coccomagnard.fr`.
4. Login web par mot de passe désactivé, redirection directe vers Authelia.
5. Admin Django (`/admin/`) toujours utilisable, mais son formulaire de connexion par mot de passe
   (`/admin/login/`) bloqué dans Caddy : on y accède avec la session ouverte par l'OIDC.
6. Note de migration `TODO(26.11)` de `paperless.nix` mise à jour (l'OIDC est désormais concerné).
7. Remarques mineures des relectures précédentes traitées dans la même PR.

## Non-objectifs

- Changer les mots de passe Paperless : ils sont forts et aléatoires, archivés dans Bitwarden.
  L'API les accepte toujours (`PAPERLESS_DISABLE_REGULAR_LOGIN` ne touche ni l'API ni l'admin, doc
  `configuration.md`) : c'est voulu, c'est le secours.
- Portail `forward_auth` devant Paperless : l'OIDC natif suffit, et le portail casserait l'API.

## Anti-objectifs

- Claire perd l'accès à ses documents (compte recréé au lieu d'être rattaché).
- Claire accède à un autre service que Paperless.
- L'app mobile ne peut plus se connecter.

## Faits vérifiés (paperless-ngx 2.20.15, django-allauth 65.16.1)

- Activation : `PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect"` et
  `PAPERLESS_SOCIALACCOUNT_PROVIDERS` (JSON, contient le secret → fichier d'env agenix
  `paperless-env`).
- Rattachement : pas de rattachement automatique par email (allauth `EMAIL_AUTHENTICATION` non
  exposé par Paperless). Chaque utilisateur, connecté par mot de passe, va dans « Mon profil » et
  connecte le compte Authelia. À faire **avant** de désactiver le login par mot de passe.
- `PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = false` : une connexion OIDC non rattachée ne crée pas
  de compte.
- Migration v3 (`docs/migration-v3.md`) : si le callback échoue en `invalid_client`, préciser
  `token_auth_method` dans `settings` du provider. On le met dès maintenant :
  `client_secret_basic` (allauth 65.16.1 le gère déjà).
- L'app mobile utilisée sait faire OIDC ou jeton d'API (dit par l'utilisateur).

## Conception

- `authelia.nix` :
  - client `paperless` : redirect `https://paperless.augendre.info/accounts/oidc/authelia/login/callback/`
    (`provider_id = "authelia"`), scopes `openid email profile`, `consent_mode = "implicit"`,
    `client_secret_basic`, politique `paperless` : `one_factor` pour `group:admins` **et**
    `group:famille`, refus sinon.
  - `authelia-users.age` : utilisateur `claire`, groupe `famille` (l'utilisateur l'ajoute avec un
    mot de passe initial qu'il transmet à Claire ; elle enregistre sa passkey, code lu dans le
    fichier du notifier). Authelia redémarre seul (`restartTriggers`).
  - Rien d'autre à changer pour l'isolement de Claire : toutes les autres règles et politiques
    exigent `group:admins`, `default_policy = "deny"`.
- `paperless.nix` : `PAPERLESS_APPS`, `PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = false` ;
  `PAPERLESS_SOCIALACCOUNT_PROVIDERS` dans `paperless-env` (`provider_id` `authelia`, `name`
  `Authelia`, `client_id` `paperless`, `server_url` `https://auth.srv-1.augendre.info`,
  `token_auth_method` `client_secret_basic`) ; un commentaire donne la forme du JSON sans le
  secret. Plus tard, après les deux rattachements : `PAPERLESS_DISABLE_REGULAR_LOGIN` et
  `PAPERLESS_REDIRECT_LOGIN_TO_SSO`.
- Vhost Paperless : `/admin/login/` répond 403.

## Ordre

1. Authelia (client, Claire) + Paperless OIDC, login par mot de passe encore actif. Déploiement.
2. Rattachement : l'utilisateur, puis Claire. Test de l'app mobile (OIDC, sinon jeton d'API).
3. Login web désactivé + redirection + blocage `/admin/login/`. Déploiement.
4. Remarques mineures, PR, merge.

Rien d'irréversible : un retour nocturne à `main` remet le login par mot de passe ; les
rattachements restent en base, sans effet sans le provider.

## Réversibilité

Retirer les réglages `PAPERLESS_*` ajoutés et le bloc `/admin/login/`, le client et l'utilisateur
`claire` d'Authelia. Les comptes et mots de passe Paperless n'ont pas changé. À ajouter à la
procédure en tête de `authelia.nix`.

## Remarques mineures intégrées

- Port d'Authelia écrit deux fois : le snippet `(sso)` passe dans `authelia.nix`
  (`services.caddy.extraConfig`), avec le port en variable.
- `adminsOneFactor` du `let` : à revoir, il servira deux fois (portail + clients) ou disparaît.
- `readeck.nix` : Readeck réécrit aussi username et email à chaque connexion OIDC (commentaire).
- Secret Transmission visible dans l'admin API de Caddy : `{env.TRANSMISSION_BASIC_AUTH}` au lieu
  de `{$…}` (lu à l'exécution, hors du JSON ; le restart sur changement de secret existe déjà).
