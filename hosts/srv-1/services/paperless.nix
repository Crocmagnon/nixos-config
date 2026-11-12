{ config, ... }:
{
  imports = [
    ./paperless-downloader.nix
    ./paperless-hass-sync.nix
  ];

  services.caddy.virtualHosts."paperless.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:9002
  '';

  # TODO(26.11): NixOS 26.11 ships paperless-ngx 3.0 (https://docs.paperless-ngx.com/migration-v3/, reviewed
  # 2026-11). Upgrading requires 2.20.15, which 26.05 runs. Beyond the inline notes below:
  # - SQLite, no barcode scanner/encryption/consume scripts/OIDC: those v3 changes don't apply.
  # - Search moves to Tantivy, the index is rebuilt on first start. A bare term no longer
  #   matches notes or custom fields (use notes.note: / custom_fields.value:); no saved view
  #   relies on that, and `created:[-3 month to now]` is still valid syntax.
  # - Allauth computes the client IP differently: if login returns 403 behind Caddy, set
  #   PAPERLESS_TRUSTED_PROXIES = "127.0.0.1" (and PAPERLESS_ALLAUTH_TRUSTED_PROXY_COUNT = 1).
  # - Task history is wiped by the migration.
  services.paperless = {
    enable = true;
    port = 9002;
    dataDir = "/var/lib/paperless";
    consumptionDirIsPublic = true; # this is required for others to write in
    domain = "paperless.augendre.info";
    exporter = {
      enable = true;
      onCalendar = "01:30";
      settings = {
        # default
        compare-checksums = true;
        delete = true;
        no-color = true;
        no-progress-bar = true;
        # custom
        no-archive = true;
        no-thumbnail = true;
        split-manifest = true;
      };
    };
    environmentFile = config.age.secrets."paperless-env".path;
    settings = {
      PAPERLESS_USE_X_FORWARD_HOST = true;
      PAPERLESS_USE_X_FORWARD_PORT = true;
      PAPERLESS_TIME_ZONE = "Europe/Paris";
      # TODO(26.11): not setting this, so tesseract (and ocrmypdf, and paperless) gets downloaded from cache instead of built from source.
      # On nixos-26.05 the module passes this setting to tesseract's enableLanguages, with no way
      # around it. nixos-unstable adds `services.paperless.tesseractLanguages`, defaulting to this
      # setting: once srv-1 is on a release that has it (26.11 expected), set
      #   tesseractLanguages = null;            # keep the cached all-languages build
      #   PAPERLESS_OCR_LANGUAGE = "fra";        # French OCR, no rebuild
      # and drop PAPERLESS_DATE_PARSER_LANGUAGES below, which then follows the OCR language.
      # Check: services.paperless.package.outPath must not change.
      # PAPERLESS_OCR_LANGUAGE = "fra";
      # Meanwhile the date parser defaults to the OCR language (eng): set it apart so French month
      # names ("25 septembre 2026") are recognised. A plain env var, no rebuild.
      PAPERLESS_DATE_PARSER_LANGUAGES = "fr+en";
      PAPERLESS_CONSUMER_ENABLE_BARCODES = true;
      PAPERLESS_CONSUMER_BARCODE_STRING = "PATCHT";
      # A duplicate (same checksum as an existing document, trash included) is refused and, with
      # this, also removed from the consumption dir instead of lingering there (v2 consumer.py).
      # paperless-ngx 3 imports duplicates by default; this setting keeps refusing and deleting them.
      PAPERLESS_CONSUMER_DELETE_DUPLICATES = true;
      PAPERLESS_TASK_WORKERS = 1;
      PAPERLESS_OCR_USER_ARGS = {
        invalidate_digital_signatures = true;
      };
      # TODO(26.11): removed in paperless-ngx 3: drop this line, its v3 equivalent
      # PAPERLESS_ARCHIVE_FILE_GENERATION = "auto" is the default there.
      PAPERLESS_OCR_SKIP_ARCHIVE_FILE = "with_text";
      PAPERLESS_WEBSERVER_WORKERS = 1;
      PAPERLESS_FILENAME_FORMAT = "{{ created_year }}/{{ correspondent }}/{{ title }}";
      # Dates printed on many documents but never their issue date: births (Gabriel, Claire,
      # Juliette) and job start dates (OVH, Ax'home).
      PAPERLESS_IGNORE_DATES = "1995-10-24,1995-10-16,2025-08-02,2023-04-03,2026-01-05";
      PAPERLESS_CONVERT_MEMORY_LIMIT = 32;
    };
  };
}
