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
      FETCHER_ALLOW_PRIVATE_NETWORKS = 1;
      INTEGRATION_ALLOW_PRIVATE_NETWORKS = 1;
      # Connexion OIDC via Authelia (authelia.nix) ; OAUTH2_CLIENT_SECRET est dans miniflux-db.
      OAUTH2_PROVIDER = "oidc";
      OAUTH2_CLIENT_ID = "miniflux";
      OAUTH2_REDIRECT_URL = "https://reader.augendre.info/oauth2/oidc/callback";
      OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://auth.srv-1.augendre.info";
      OAUTH2_USER_CREATION = 0;
      # Retour arrière : retirer cette ligne ET les OAUTH2_* dans le même déploiement.
      DISABLE_LOCAL_AUTH = 1;
    };
  };
}
