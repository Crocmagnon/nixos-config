# Authelia : une seule connexion (passkey) pour les services internes.
# Conception : docs/superpowers/specs/2026-11-24-sso-authelia-design.md
#
# - Portail et fournisseur OIDC sur auth.srv-1.augendre.info (wildcard DNS *.srv-1 → Tailscale).
# - Clients OIDC : readeck, miniflux. Derrière le portail (`import sso`) : calibre-web, stirling,
#   prowlarr, radarr, sonarr, transmission.
# - Ajouter un utilisateur : éditer authelia-users.age (hash : `authelia crypto hash generate argon2`),
#   puis déployer : Authelia redémarre seul (restartTriggers ci-dessous).
#
# Retirer Authelia (les comptes locaux des apps n'ont jamais été supprimés) :
#   1. miniflux.nix : retirer DISABLE_LOCAL_AUTH et les OAUTH2_* dans le MÊME déploiement, et
#      remettre WEBAUTHN = 1 (passkeys Miniflux, toujours en base).
#   2. readeck.nix : retirer `auth.oidc`. Le compte reste marqué externe (login par mot de passe
#      OK, mais l'UI refuse d'en changer le mot de passe, le username ou l'email). Pour le libérer :
#      UPDATE "user" SET ext_id = NULL, ext_info = NULL; sur la base PostgreSQL de Readeck.
#      Garder readeck d'unstable : redescendre en 0.22 après les migrations 0.23 n'est pas sûr.
#   3. calibre-web.nix : retirer reverseProxyAuth (le module remet le réglage à 0 en base).
#      paperless.nix : retirer les PAPERLESS_* du SSO et le blocage de /admin/login/, et
#      PAPERLESS_SOCIALACCOUNT_PROVIDERS de paperless-env (comptes et mots de passe inchangés).
#   4. servarr.nix : retirer `settings.auth.method = "External"` (le login Forms des *arr revient)
#      et le `header_up Authorization` de Transmission (sa demande de mot de passe revient).
#   5. Retirer les `import sso`, ce fichier (et avec lui le snippet (sso)), son import dans
#      default.nix, le chemin restic, les secrets authelia-* et caddy-transmission-env
#      (agenix-rules.nix, default.nix, EnvironmentFile de caddy.nix).
#   6. Facultatif : rm -rf /var/lib/authelia-main sur srv-1. Rien à faire côté DNS.
#   Mots de passe locaux oubliés : `readeck user -password`, `miniflux -reset-password`,
#   `calibre-web -s user:pass`.
{ config, ... }:
let
  secret = name: config.age.secrets."authelia-${name}".path;
  stateDir = "/var/lib/authelia-main";
  port = 9092; # 9091 est pris par le RPC de Transmission
in
{
  services.authelia.instances.main = {
    enable = true;
    secrets = {
      jwtSecretFile = secret "jwt";
      storageEncryptionKeyFile = secret "storage-key";
      oidcHmacSecretFile = secret "oidc-hmac";
      oidcIssuerPrivateKeyFile = secret "oidc-jwk";
    };
    settings = {
      server.address = "tcp://127.0.0.1:${toString port}/";
      log.format = "text";

      authentication_backend = {
        file.path = secret "users";
        # Fichier agenix en lecture seule : on modifie les comptes dans le repo.
        password_change.disable = true;
        password_reset.disable = true;
      };

      webauthn.enable_passkey_login = true;

      session.cookies = [
        {
          # Pas augendre.info : le cookie partirait vers les sous-domaines hébergés ailleurs.
          domain = "srv-1.augendre.info";
          authelia_url = "https://auth.srv-1.augendre.info";
          remember_me = "1M";
        }
      ];

      storage.local.path = "${stateDir}/db.sqlite3";
      # Pas de serveur mail : les codes de vérification se lisent ici, en SSH.
      notifier.filesystem.filename = "${stateDir}/notification.txt";

      access_control = {
        default_policy = "deny";
        rules = [
          {
            domain = [
              "books.srv-1.augendre.info"
              "pdf.srv-1.augendre.info"
              "prowlarr.srv-1.augendre.info"
              "radarr.srv-1.augendre.info"
              "sonarr.srv-1.augendre.info"
              "transmission.srv-1.augendre.info"
            ];
            policy = "one_factor";
            subject = "group:admins";
          }
          {
            # Sans aucune règle two_factor, Authelia masque l'enregistrement des passkeys.
            # Ce domaine ne sert à rien d'autre (rien n'y répond).
            domain = "enable-passkeys.srv-1.augendre.info";
            policy = "two_factor";
          }
        ];
      };

      identity_providers.oidc = {
        authorization_policies = {
          admins_one_factor = {
            default_policy = "deny";
            rules = [
              {
                policy = "one_factor";
                subject = "group:admins";
              }
            ];
          };
          # Paperless : le seul service ouvert au groupe famille (Claire).
          paperless = {
            default_policy = "deny";
            rules = [
              {
                policy = "one_factor";
                subject = [
                  "group:admins"
                  "group:famille"
                ];
              }
            ];
          };
        };
        clients = [
          {
            client_id = "readeck";
            client_name = "Readeck";
            client_secret = "$pbkdf2-sha512$310000$E/1jGuUBjdUidFoQcRqf4Q$vrrGGVANn1li9EqUvEK/MZNmduRROxjoqDp0nwe7GngLRz.HTjz.59MCuKjRkyhcliTrgTq5CpzMbEpEuYyVkQ";
            authorization_policy = "admins_one_factor";
            consent_mode = "implicit"; # nos propres apps : pas d'écran de consentement
            redirect_uris = [ "https://readeck.augendre.info/login/oidc" ];
            scopes = [
              "openid"
              "email"
              "profile"
              "groups"
            ];
            require_pkce = true;
            pkce_challenge_method = "S256";
            token_endpoint_auth_method = "client_secret_basic";
          }
          {
            client_id = "miniflux";
            client_name = "Miniflux";
            client_secret = "$pbkdf2-sha512$310000$myTRgc3WbJCoTid5Afv9qQ$xVgyegwRRAzAPtzI6eyr0dMdId2DhsB8VLF7TMXDB2hgnhdbniK6ONb8OZ1hR/j0jYYSCZcTkhGDps8Fc1pnsg";
            authorization_policy = "admins_one_factor";
            consent_mode = "implicit"; # nos propres apps : pas d'écran de consentement
            redirect_uris = [ "https://reader.augendre.info/oauth2/oidc/callback" ];
            scopes = [
              "openid"
              "email"
              "profile"
            ];
            token_endpoint_auth_method = "client_secret_basic";
          }
          {
            client_id = "paperless";
            client_name = "Paperless";
            client_secret = "$pbkdf2-sha512$310000$njU3whPMnNU4V5UGSSUkLw$gWhmHruh4Ba41pNdRUtYpnAXFB0fswLh9UdYVCkhX/8P3y88Yg3XL4.ec9r9xEErog//yDJrswmRd4kqRnUvJg";
            authorization_policy = "paperless";
            consent_mode = "implicit";
            # provider_id "authelia" dans PAPERLESS_SOCIALACCOUNT_PROVIDERS (paperless-env).
            redirect_uris = [ "https://paperless.augendre.info/accounts/oidc/authelia/login/callback/" ];
            scopes = [
              "openid"
              "email"
              "profile"
            ];
            token_endpoint_auth_method = "client_secret_basic";
          }
        ];
      };
    };
  };

  # Authelia ne relit pas le fichier des utilisateurs, et `file.watch` ne verrait pas le changement :
  # agenix fait pointer /run/agenix vers un nouveau dossier au lieu de réécrire le fichier.
  # Son empreinte (et non son chemin, qui est celui de tout le dépôt) ne change qu'avec lui.
  systemd.services.authelia-main.restartTriggers = [
    (builtins.hashFile "sha256" config.age.secrets."authelia-users".file)
  ];

  # Portail Authelia (`import sso`), en plus de `import internal`. Caddy retire de lui-même
  # les en-têtes Remote-* envoyés par le client avant de copier ceux d'Authelia.
  services.caddy.extraConfig = ''
    (sso) {
      forward_auth 127.0.0.1:${toString port} {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
      }
    }
  '';

  services.caddy.virtualHosts."auth.srv-1.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy 127.0.0.1:${toString port}
  '';
}
