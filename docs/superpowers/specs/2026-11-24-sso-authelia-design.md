# SSO Authelia sur srv-1 — étape 1

## Intention

L'utilisateur en a assez d'avoir une entrée de gestionnaire de mots de passe par service
auto-hébergé : sur iOS le remplissage marche mal, même avec les bonnes URLs. Il veut **une seule
connexion pour tout `*.augendre.info`** : connecté sur Miniflux, il arrive sur Readeck sans se
reconnecter. Tout doit être en config versionnée dans ce repo, sans clic dans des UI d'admin
(une action manuelle ponctuelle est tolérée quand rien d'autre n'existe).

Tous les services concernés sont déjà derrière `import internal` (Tailscale uniquement) : le SSO
ne remplace pas cette barrière, il remplace les logins applicatifs qui restent derrière.

Cette étape ne couvre que des services que l'utilisateur est seul à utiliser, pour roder
Authelia sans risque pour quelqu'un d'autre.

## Objectifs

1. Authelia tourne sur srv-1 et sert `auth.srv-1.augendre.info` (portail + fournisseur OIDC).
2. Une seule connexion vaut pour tous les services concernés : par OIDC pour ceux qui le gèrent
   (quel que soit leur domaine), par le cookie de session `srv-1.augendre.info` pour ceux derrière
   le portail.
3. Connexion par **passkey** (Face ID sur iOS), mot de passe en secours.
4. Readeck et Miniflux se connectent en **OIDC natif**.
5. Calibre-web se connecte par **en-tête** (`Remote-User`) posé par Caddy après le portail.
6. Stirling-PDF est derrière le **portail seul** (il n'a pas de login).
7. Tout est déclaré dans Nix + agenix.

## Non-objectifs (étape 1)

- Paperless et le compte de Claire : étape 2 (voir plus bas, à ne pas casser dès maintenant).
- Sonarr, Radarr, Prowlarr, Transmission : plus tard. Ils ont déjà leur propre login (Forms
  pour Sonarr/Radarr, mot de passe RPC pour Transmission) et se parlent par `localhost`, sans
  passer par Caddy.
- Jellyfin : exclu (les apps TV/mobile ne savent pas passer un portail web), garde son login.
- recettes-cabas et ESPHome : exclus, seulement appelés en API par Home Assistant.
- Galène : exclu, public pour des invités.
- Serveur mail : les notifications d'Authelia vont dans un fichier.
- Exposer quoi que ce soit hors Tailscale.

## Anti-objectifs

- Perdre ses droits admin ou ses données dans une app parce que la connexion SSO a créé un
  compte neuf au lieu de rattacher l'existant.
- Casser une app mobile ou un accès API existant (app Readeck, clients Miniflux) en mettant le
  portail devant.
- Pouvoir se faire passer pour quelqu'un en envoyant soi-même un en-tête `Remote-User`.
- Une config qui demande de repasser dans une UI d'admin à chaque déploiement.
- Des hash de mots de passe ou des secrets en clair dans ce repo public.

## Contraintes

- srv-1 est en NixOS 26.05. Authelia y est en 4.39.20 (module `services.authelia.instances`).
- Readeck : l'OIDC arrive en 0.23.0 (bug Chromium corrigé en 0.23.4). Stable a 0.22.3,
  unstable 0.23.5 → ajouter `readeck` à `inherit (unstable)` dans
  `overlays/unstable-packages.nix` (décision prise).
- Miniflux 2.3.5 en prod, Calibre-web 0.6.26.
- Readeck (8006), Miniflux (8001), Calibre-web (8005), Stirling (8004) écoutent déjà sur
  `127.0.0.1` : seul Caddy les atteint, condition de sûreté de l'auth par en-tête.
- Secrets via agenix (`hosts/srv-1/age/agenix-rules.nix` + `agenix -e`, dérivés en
  `age.secrets` automatiquement). Le repo est public.
- Ce qui est sur `main` part en prod la nuit (auto-upgrade). Une étape qui demande une action
  manuelle entre deux déploiements doit être sur une branche ou découpée en PR successives.

## Approches envisagées

- **Authelia (retenue).** Fait à la fois fournisseur OIDC et portail `forward_auth` pour Caddy,
  module NixOS natif, config YAML entièrement déclarative, utilisateurs dans un fichier, SQLite,
  léger, passkeys. Pas d'UI d'admin, ce qui est voulu.
- **Kanidm.** Passkeys au centre, provisioning déclaratif des comptes et clients OIDC, mais pas
  de portail : il faudrait oauth2-proxy en plus pour Stirling puis les \*arr. Plus exigeant à
  installer.
- **Pocket ID.** Le plus simple, passkeys only, mais utilisateurs et clients se créent dans
  l'UI : contraire à l'objectif de config versionnée. Pas de portail non plus.
- Authentik et Keycloak : écartés, trop lourds pour un serveur perso.

Choix de l'utilisateur : Authelia.

## Conception

### Authelia

- Une instance `services.authelia.instances.main`, écoute sur `127.0.0.1`, vhost Caddy
  `auth.srv-1.augendre.info` avec `import common_headers` + `import internal`.
- Nom d'hôte (choix de conception) : `auth.srv-1.augendre.info` plutôt que `auth.augendre.info`.
  Le wildcard DNS `*.srv-1.augendre.info` pointe déjà sur l'IP Tailscale de srv-1 (vérifié avec
  `dig`) : aucun enregistrement DNS à créer ni à retirer. Et le cookie de session reste limité à
  `srv-1.augendre.info` : un cookie sur `augendre.info` partirait aussi vers les sous-domaines
  hébergés ailleurs (`qr.augendre.info` sur GitHub Pages…). Readeck et Miniflux, en OIDC, n'ont
  besoin que du cookie sur l'hôte d'Authelia ; les vhosts du portail, étape 2 comprise, sont tous
  en `*.srv-1.augendre.info`.
- Session : un cookie pour le domaine `srv-1.augendre.info`, `authelia_url =
  https://auth.srv-1.augendre.info`.
- Stockage : SQLite dans `/var/lib/authelia-main`. Ce chemin n'est couvert par aucun chemin
  restic actuel : l'ajouter à `restic.nix`.
- Notifier : `filesystem`. Le code de vérification demandé à l'enregistrement d'une passkey se
  lit en SSH dans ce fichier.
- Utilisateurs : backend `file`. Le fichier `users_database.yml` (hash argon2) est un secret
  agenix, pas un fichier du repo (anti-objectif « hash en clair »). Changement et reset de mot de
  passe désactivés dans Authelia, puisque le fichier est en lecture seule.
- Un utilisateur pour l'étape 1, `gaugendre`, email `gabriel@augendre.info`, groupe `admins`.
- WebAuthn : passkeys activées en connexion directe (sans mot de passe préalable). Mot de passe
  en secours.
- Politique : `default_policy: deny`. Les vhosts derrière le portail (Calibre-web, Stirling)
  exigent `one_factor` pour le groupe `admins` (une passkey suffit ; Tailscale fait déjà office
  de second facteur réseau). Les clients OIDC ont la même règle via une
  `authorization_policies` nommée (`admins` en `one_factor`) : leur défaut est `two_factor`, et
  en 4.39 une passkey seule ne compte que pour un facteur.
- Clients OIDC (choix de conception) : déclarés en Nix dans `settings`, avec le **digest**
  (pbkdf2) de leur secret. Un digest d'un secret aléatoire de 64 caractères ne donne rien
  d'exploitable, il peut être dans le repo public. Le secret en clair n'existe que côté app,
  en agenix.
- Secrets agenix : secret JWT de validation d'identité, secret de session, clé de chiffrement
  du stockage, secret HMAC OIDC, clé privée de signature OIDC (JWKS), secrets des clients OIDC.
  Le module NixOS sait lire la plupart de ces secrets depuis des fichiers (`secrets.*File`) ;
  pour le reste, `settingsFiles` ou les variables `AUTHELIA_*_FILE`.

### Caddy

Un snippet `(sso)` dans `hosts/srv-1/services/caddy.nix`, sur le modèle de `(internal)` :
`forward_auth` vers Authelia (endpoint `/api/authz/forward-auth`) avec
`copy_headers Remote-User Remote-Groups Remote-Email Remote-Name`. Les vhosts derrière le
portail font `import internal` **et** `import sso`.

Contrainte de sûreté : un `Remote-User` envoyé par le client ne doit jamais atteindre l'app.
Vérifier que `forward_auth`/`copy_headers` de la version de Caddy en prod supprime l'en-tête
quand la réponse d'Authelia ne le contient pas ; sinon, le retirer explicitement
(`request_header -Remote-User` etc.) avant `forward_auth`.

### Readeck (OIDC)

- Paquet unstable (≥ 0.23.4).
- `settings.auth.oidc.providers` : `name = "Authelia"`, `url = "https://auth.srv-1.augendre.info"`,
  `client_id = "readeck"`, `groups = [["admins", "admin"]]`, `provisioning = false`
  (le rattachement d'un compte existant se fait quand même ; `false` empêche seulement de créer
  un compte neuf : un mauvais rattachement donne une erreur plutôt qu'un compte vide).
  `client_secret` via `READECK_AUTH_OIDC_PROVIDERS_0_CLIENT_SECRET` dans le fichier
  d'environnement agenix `readeck-env`. L'index doit être `0` pour fusionner avec le provider
  déclaré dans `settings` ; un autre ajoute un second provider incomplet et Readeck refuse de
  démarrer.
  L'utilisateur repassera `provisioning` à `true` plus tard, pour créer facilement des comptes
  (Claire ou d'autres) ; hors étape 1.
- TOTP Readeck : l'utilisateur l'a désactivé (sinon Readeck le redemandait après l'OIDC).
- **Piège :** à chaque connexion OIDC, Readeck réécrit le groupe du compte depuis les groupes
  reçus, `user` par défaut. Sans le mapping `admins → admin`, l'utilisateur perd son rôle admin
  à la première connexion.
- Rattachement : Readeck rattache un compte existant si `username` **ou** `email` correspond
  (`internal/auth/oidc/provisioning.go`). Vérifier que le compte Readeck existant a le username
  `gaugendre` ou l'email `gabriel@augendre.info`, sinon un compte neuf est créé.
- Pas de redirection automatique vers le SSO ni de désactivation du login local : un bouton
  « Authelia » sur l'écran de login, un clic. Accepté.
- Client Authelia : redirect URI `https://readeck.augendre.info/login/oidc`, scopes `openid
  email profile groups`, PKCE S256 (Readeck le gère).
- Pas de portail devant Readeck : l'app mobile et l'API gardent leurs tokens OAuth Readeck.

### Miniflux (OIDC)

- `OAUTH2_PROVIDER = "oidc"`, découverte sur `https://auth.srv-1.augendre.info`, redirect
  `https://reader.augendre.info/oauth2/oidc/callback`, client `miniflux`, secret par fichier
  (`OAUTH2_CLIENT_SECRET_FILE` ou fichier d'environnement agenix).
- `OAUTH2_USER_CREATION` désactivé : un seul compte, à rattacher.
- Rattachement : manuel, une fois, depuis les réglages Miniflux (« lier mon compte OpenID
  Connect ») en étant connecté avec le mot de passe local. C'est l'action manuelle acceptée.
- Puis `DISABLE_LOCAL_AUTH = 1`, **dans un second déploiement**, après le rattachement (sinon
  plus aucun moyen de se connecter). Vérifié dans les sources 2.3.5 : l'option masque le
  formulaire de mot de passe, mais l'écran de login garde un bouton OIDC (un clic, comme
  Readeck ; pas de redirection automatique). Elle **bloque l'API en Basic auth** : les clients
  API doivent utiliser une clé d'API (`X-Auth-Token`). Fever et Google Reader ont leurs propres
  identifiants d'intégration et ne sont pas concernés. Le seul client API connu est le plugin
  KOReader `miniflux-download-koreader` de l'utilisateur, qui s'authentifie par clé d'API
  (`X-Auth-Token`, `api.lua`) : non concerné.
- La « 2FA » Miniflux de l'utilisateur est en fait une passkey (`WEBAUTHN = 1`) : Miniflux n'a
  pas de TOTP. C'est une méthode de connexion alternative, pas un second facteur : la connexion
  OIDC ne la demande pas, et `WEBAUTHN` reste activé (passkey Miniflux utilisable en secours).
- Pas de portail devant Miniflux.

### Calibre-web (en-tête)

- `options.reverseProxyAuth.enable = true`, `header = "Remote-User"` (option du module NixOS,
  écrite dans la base au démarrage : déclaratif).
- L'utilisateur lit via **KOReader** (OPDS), qui ne sait pas passer le portail : `/opds*` reste
  **hors** du portail (matcher dans le vhost), avec l'auth Basic de Calibre-web. Le reste du vhost
  fait `import internal` + `import sso`.
- Sur le chemin `/opds*`, pas de `forward_auth`, donc rien ne retire un `Remote-User` envoyé par
  le client : le retirer explicitement (`request_header -Remote-User` sur ce chemin, ou pour
  tout le vhost avant `forward_auth`). Sinon n'importe quel client du tailnet se connecte en
  admin en posant l'en-tête.
- Vérifier dans calibre-web 0.6.26 qu'avec `reverseProxyAuth` actif, une requête OPDS sans
  en-tête retombe bien sur l'auth Basic (et ne la refuse pas).
- Calibre-web ne crée pas d'utilisateur à la volée : le username Authelia doit être celui du
  compte Calibre-web existant. Le vérifier dans `app.db` ; si différent, renommer côté Authelia
  ou côté Calibre-web (renommer en base une fois est acceptable).

### Stirling-PDF (portail seul)

- Vhost `pdf.srv-1.augendre.info` : `import internal` + `import sso`. Rien d'autre.

## Ordre de déploiement

Comme `main` part en prod la nuit, découper pour qu'aucun état intermédiaire ne bloque :

1. Authelia + snippet Caddy + Stirling derrière le portail. Enregistrer la passkey (code lu dans
   le fichier du notifier).
2. Readeck (unstable + OIDC) et Calibre-web (en-tête).
3. Miniflux OIDC sans `DISABLE_LOCAL_AUTH` → rattachement manuel du compte.
4. `DISABLE_LOCAL_AUTH`.

Les étapes 1–3 peuvent être une seule PR si l'utilisateur teste via `mise run srv-1` avant de
merger ; l'étape 4 est un commit à part, après le rattachement.

## Réversibilité

Exigence de l'utilisateur : pouvoir retirer Authelia si on fait marche arrière, avec le moins
d'actions manuelles possible (quelques-unes sont acceptées). Conséquences sur la conception :

- **Les comptes locaux ne sont jamais supprimés** et gardent leur mot de passe : le rattachement
  OIDC de Readeck et Miniflux ne touche pas au mot de passe, et Calibre-web garde le sien. Rien
  dans cette étape ne doit les effacer ou les rendre inutilisables. Les mots de passe peuvent
  quitter le gestionnaire : ils se réinitialisent en CLI sur srv-1 (`readeck user -password`,
  `miniflux -reset-password`, `calibre-web -s user:pass`).
- Chaque app se branche par quelques lignes isolées (un bloc de config, un `import sso`), de sorte
  que le retour arrière soit un `git revert` ou la suppression de ces lignes.
- La procédure de retrait est écrite dans un commentaire en tête de `authelia.nix` (même usage
  que le commentaire de passage en lecture/écriture de `calibre-web.nix`).

Retour arrière, une fois tout en place :

1. Miniflux : retirer `DISABLE_LOCAL_AUTH` et la config `OAUTH2_*` dans le **même** déploiement,
   sinon plus aucun moyen de se connecter. Déclaratif.
2. Readeck : retirer le provider. Le compte rattaché reste marqué « externe » (`ext_id` en
   base) : le login par mot de passe marche encore (le formulaire de connexion ne regarde pas
   `ext_id`), mais l'UI refuse de changer son mot de passe, son username ou son email.
   **Action manuelle** pour le libérer : `UPDATE "user" SET ext_id = NULL, ext_info = NULL`
   sur la base Readeck (PostgreSQL OVH). Le paquet unstable **reste** : redescendre en 0.22
   après les migrations de la 0.23 n'est pas sûr, et 26.11 l'apportera en stable.
3. Calibre-web : `reverseProxyAuth.enable = false`. Le module réécrit le réglage en base à
   chaque démarrage, donc déclaratif.
4. Stirling, Calibre-web : retirer `import sso`.
5. Retirer `authelia.nix`, le snippet `(sso)`, le vhost et les secrets agenix.
   **Action manuelle** facultative : `rm -rf /var/lib/authelia-main` sur srv-1. Rien côté DNS
   (wildcard).

## Étape 2 (hors périmètre, à ne pas fermer)

- Paperless en OIDC (allauth), utilisé par l'utilisateur et Claire, **tous deux via l'app
  mobile Paperless** : vérifier comment l'app s'authentifie (token API) avant de désactiver le
  login local.
- Comptes Paperless existants : `gabriel@augendre.info` et `claire@coccomagnard.fr`. Vérifier
  dans allauth comment un compte existant est rattaché (par email ?).
- Claire : un utilisateur Authelia, groupe dédié (`famille`), autorisé seulement sur Paperless
  (`authorization_policy` du client OIDC). La conception de l'étape 1 ne doit donc pas supposer
  un seul utilisateur (politiques par groupe dès maintenant).
- \*arr et Transmission derrière le portail, en gardant leurs accès `localhost`.

## Laissé au constructeur

- Port d'Authelia, noms des secrets agenix, découpage en fichiers (`authelia.nix` dans
  `hosts/srv-1/services/`, ajouté à `default.nix`).
- Durées de session. Proposition : `remember_me` long (de l'ordre du mois), puisque le but est
  de ne pas se reconnecter.
- Les vérifications marquées « vérifier » ci-dessus, faites dans le code ou sur srv-1 avant
  d'écrire la config correspondante.
