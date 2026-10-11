{ config, ... }:
{
  imports = [
    ./paperless-downloader.nix
    ./paperless-hass-sync.nix
  ];

  services.caddy.virtualHosts."paperless.augendre.info".extraConfig = ''
    import common_headers
    import internal_agent
    reverse_proxy localhost:9002
  '';

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
      # Not setting this, so tesseract (and ocrmypdf, and paperless) gets downloaded from cache instead of built from source.
      # PAPERLESS_OCR_LANGUAGE = "fra";
      PAPERLESS_CONSUMER_ENABLE_BARCODES = true;
      PAPERLESS_CONSUMER_BARCODE_STRING = "PATCHT";
      PAPERLESS_TASK_WORKERS = 1;
      PAPERLESS_OCR_USER_ARGS = {
        invalidate_digital_signatures = true;
      };
      PAPERLESS_OCR_SKIP_ARCHIVE_FILE = "with_text";
      PAPERLESS_WEBSERVER_WORKERS = 1;
      PAPERLESS_FILENAME_FORMAT = "{{ created_year }}/{{ correspondent }}/{{ title }}";
      PAPERLESS_IGNORE_DATES = "1995-10-24,1995-10-16";
      PAPERLESS_CONVERT_MEMORY_LIMIT = 32;
    };
  };
}
