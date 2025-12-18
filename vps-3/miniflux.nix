{config, ...}:{
  services.miniflux = {
    enable = true;
    createDatabaseLocally = false;
    adminCredentialsFile = config.age.secrets."miniflux-db".path;
    config = {
      POLLING_FREQUENCY=2;
      LISTEN_ADDR="127.0.0.1:8008";
      LOG_DATE_TIME=1;
      LOG_FORMAT="text";
      LOG_FILE="stdout";
      LOG_LEVEL="info";
      WORKER_POOL_SIZE=10;
      BATCH_SIZE=20;
      BASE_URL="https://reader.augendre.info/";
      WEBAUTHN=1;
      RUN_MIGRATIONS=1;
      HTTPS=1;
      DISABLE_HSTS=1;
      FETCH_YOUTUBE_WATCH_TIME=0;
      POLLING_PARSING_ERROR_LIMIT="50";
      CREATE_ADMIN=false;
    };
  };
}