{ config, ... }:
{
  services.caddy.virtualHosts."reader.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:8001
  '';

  services.miniflux = {
    enable = true;
    createDatabaseLocally = false;
    adminCredentialsFile = config.age.secrets."miniflux-db".path;
    config = {
      POLLING_FREQUENCY = 2;
      LISTEN_ADDR = "127.0.0.1:8001";
      LOG_DATE_TIME = 1;
      LOG_FORMAT = "text";
      LOG_FILE = "stdout";
      LOG_LEVEL = "info";
      WORKER_POOL_SIZE = 10;
      BATCH_SIZE = 20;
      BASE_URL = "https://reader.augendre.info/";
      # Passkeys Miniflux désactivées (le SSO les remplace) mais gardées en base : remettre 1 pour les retrouver.
      WEBAUTHN = 0;
      RUN_MIGRATIONS = 1;
      HTTPS = 1;
      DISABLE_HSTS = 1;
      FETCH_YOUTUBE_WATCH_TIME = 0;
      POLLING_PARSING_ERROR_LIMIT = "50";
      CREATE_ADMIN = false;
      # Pas de flux sur le réseau local : sinon tout compte (Claire, depuis l'OIDC) ferait lire à srv-1
      # les services de localhost, sans auth depuis le portail (*arr, Calibre-web).
      FETCHER_ALLOW_PRIVATE_NETWORKS = 0;
      INTEGRATION_ALLOW_PRIVATE_NETWORKS = 1;
      # Connexion OIDC via Authelia (authelia.nix) ; OAUTH2_CLIENT_SECRET est dans miniflux-db.
      OAUTH2_PROVIDER = "oidc";
      OAUTH2_CLIENT_ID = "miniflux";
      OAUTH2_REDIRECT_URL = "https://reader.augendre.info/oauth2/oidc/callback";
      OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://auth.srv-1.augendre.info";
      OAUTH2_USER_CREATION = 1; # compte créé à la première connexion OIDC (Claire)
      # Retour arrière : retirer cette ligne ET les OAUTH2_* dans le même déploiement.
      DISABLE_LOCAL_AUTH = 1;
    };
  };

  # Le secret client OIDC est dans miniflux-db : redémarrer quand il change (même principe qu'Authelia).
  systemd.services.miniflux.restartTriggers = [
    (builtins.hashFile "sha256" config.age.secrets."miniflux-db".file)
  ];
}
