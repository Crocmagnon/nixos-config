{ config, pkgs, pkgs-release, ... }:
{
  environment.systemPackages = with pkgs; [
    s3fs
  ];
  fileSystems."s3-paperless" = {
    device = "paperless-gaugendre";
    mountPoint = "/mnt/paperless";
    fsType = "fuse./run/current-system/sw/bin/s3fs";
    noCheck = true;
    options = [ "_netdev" "allow_other" "use_path_request_style" "url=https://s3.gra.io.cloud.ovh.net/" "passwd_file=${config.age.secrets."paperless-s3-creds".path}" ];
  };
  services.paperless = let
    domain = "paperless.augendre.info";
  in {
    enable = true;
    package = pkgs-release.paperless-ngx; # https://github.com/NixOS/nixpkgs/issues/472792
    port = 9002;
    dataDir = "/mnt/paperless";
    domain = domain;
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
}
