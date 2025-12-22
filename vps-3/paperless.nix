{ config, pkgs, lib, pkgs-pw, ... }:
let
  downloader = pkgs.buildGoModule {
    pname = "downloader-go";
    version = "latest";
    src = pkgs.fetchFromGitea {
      domain = "codeberg.org";
      owner = "Crocmagnon";
      repo = "downloader-go";
      rev = "54c93d7df746549b4c0f2d0af6949b2335916dd3";
      hash = "sha256-nRxkmIzo4Qfo7qV/YANjic2gs/CAn4IebRbzZbEWisc=";
    };
    vendorHash = "sha256-6n0QsQVxZXD33wMIxbgnduoQiW+elvIUYnCWhCRmQl4=";
  };
in
{
  environment.systemPackages = [
    downloader
    pkgs-pw.playwright-driver.browsers
    pkgs-pw.playwright-driver
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
      path = "/var/lib/paperless/consume";
      devices = ["ubuntu"];
    };
  };

  systemd.timers = {
    download-shiva = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-10 13:00";
        Persistent = true;
      };
    };
  };

  systemd.tmpfiles.settings."downloader-cache"."${config.services.paperless.dataDir}/.cache/downloader".d = {
    inherit (config.services.paperless) user;
    inherit (config.users.users.${config.services.paperless.user}) group;
  };

  systemd.services = {
    download-shiva = {
      # path = [ downloader ];
      restartIfChanged = false;
      # startAt = "*-*-10 13:00";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        PLAYWRIGHT_BROWSERS_PATH = pkgs-pw.playwright-driver.browsers;
        PLAYWRIGHT_DRIVER_PATH = pkgs-pw.playwright-driver;
        PLAYWRIGHT_NODEJS_PATH = "${pkgs.nodejs}/bin/node";
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1";
      };
      serviceConfig = {
        WorkingDirectory = config.services.paperless.dataDir+"/.cache/downloader";
        Type = "oneshot";
        User = config.services.paperless.user;
        EnvironmentFile = config.age.secrets."downloader-creds-env".path;
        ExecStart = ''
          ${downloader}/bin/downloader-go shiva --headless -o ${config.services.paperless.consumptionDir} -u $SHIVA_USERNAME -p $SHIVA_PASSWORD
        '';
      };
    };
  };
}
