{ config, ... }:
{
  imports = [
    ./paperless-downloader.nix
  ];
  
  services.paperless = {
    enable = true;
    port = 9002;
    dataDir = "/var/lib/paperless";
    consumptionDirIsPublic = true; # this is required for syncthing to write
    domain = "paperless.augendre.info";
    exporter = {
      enable = true;
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
      PAPERLESS_OCR_LANGUAGE = "fra";
      PAPERLESS_CONSUMER_ENABLE_BARCODES=true;
      PAPERLESS_CONSUMER_BARCODE_STRING="PATCHT";
      PAPERLESS_TASK_WORKERS=1;
      PAPERLESS_OCR_USER_ARGS={ invalidate_digital_signatures = true; };
      PAPERLESS_OCR_SKIP_ARCHIVE_FILE="with_text";
      PAPERLESS_WEBSERVER_WORKERS=1;
      PAPERLESS_FILENAME_FORMAT="{{ created_year }}/{{ correspondent }}/{{ title }}";
      PAPERLESS_IGNORE_DATES="1995-10-24,1995-10-16";
      PAPERLESS_CONVERT_MEMORY_LIMIT=32;
    };
  };

  services.syncthing = {
    enable = true;
    guiPasswordFile = config.age.secrets."syncthing-gui-password".path;
    guiAddress = "100.82.177.24:8384";
    settings.devices.ubuntu = {
      id = "OCM3L3Y-S32GASE-V2GENIK-VH4K4GN-R22IADT-L6G4EKJ-QEVATXM-I6SH3QE";
    };
    settings.options.urAccepted = -1;
    settings.folders.paperless = {
      id = "ktdnd-aoxva";
      type = "sendreceive";
      path = config.services.paperless.consumptionDir;
      devices = ["ubuntu"];
    };
  };
}
