{
  pkgs,
  pkgs-pw,
  config,
  lib,
  ...
}:
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
  downloads = {
    shiva = {      calendar = "*-*-10 13:00";      subcommand = "shiva";      var = "$SHIVA";    };
  };
in {
  systemd.tmpfiles.settings."downloader-cache"."${config.services.paperless.dataDir}/.cache/downloader".d = {
    inherit (config.services.paperless) user;
    inherit (config.users.users.${config.services.paperless.user}) group;
  };

  systemd.timers = lib.mapAttrs' (
      name: value: lib.nameValuePair "download-${name}" {
        wantedBy = [ "timers.target" ];
        timerConfig.OnCalendar = value.calendar;
        timerConfig.Persistent = true;
      }
    ) downloads;

  systemd.services = lib.mapAttrs' (
    name: value: lib.nameValuePair "download-${name}" {
      restartIfChanged = false;
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        PLAYWRIGHT_BROWSERS_PATH = pkgs-pw.playwright-driver.browsers;
        PLAYWRIGHT_DRIVER_PATH = pkgs-pw.playwright-driver;
        PLAYWRIGHT_NODEJS_PATH = "${pkgs.nodejs}/bin/node";
      };
      serviceConfig = {
        WorkingDirectory = config.services.paperless.dataDir+"/.cache/downloader";
        Type = "oneshot";
        User = config.services.paperless.user;
        EnvironmentFile = config.age.secrets."downloader-creds-env".path;
        ExecStart = ''
          ${downloader}/bin/downloader-go ${value.subcommand} --no-interaction --headless -o ${config.services.paperless.consumptionDir} -u ${value.var}_USERNAME -p ${value.var}_PASSWORD
        '';
      };
  }) downloads;
}
