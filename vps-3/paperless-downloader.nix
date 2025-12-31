{
  pkgs,
  config,
  lib,
  ...
}:
let
  downloads = {
    shiva = {
      calendar = "*-*-10 13:00";
      subcommand = "shiva";
      var = "$SHIVA";
    };
    eau-du-grand-lyon = {
      calendar = "*-6,12-13 13:00";
      subcommand = "eau-du-grand-lyon";
      var = "$EDG";
    };
    free-mobile = {
      calendar = "*-*-2 13:00";
      subcommand = "free-mobile";
      var = "$FREEMOBILE";
    };
    freebox = {
      calendar = "*-*-5 13:00";
      subcommand = "freebox";
      var = "$FREEBOX";
    };
    lcl = {
      calendar = "*-*-10 13:00";
      subcommand = "lcl";
      var = "$LCL";
    };
    # octopus = {
    #   calendar = "";
    #   subcommand = "octopus-energy-address";
    #   var = "$OCTOPUS";
    # };
  };
in
{
  systemd.tmpfiles.settings."downloader-cache"."${config.services.paperless.dataDir}/.cache/downloader".d =
    {
      inherit (config.services.paperless) user;
      inherit (config.users.users.${config.services.paperless.user}) group;
    };

  systemd.timers = lib.mapAttrs' (
    name: value:
    lib.nameValuePair "download-${name}" {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = value.calendar;
      timerConfig.Persistent = true;
    }
  ) downloads;

  systemd.services = lib.mapAttrs' (
    name: value:
    lib.nameValuePair "download-${name}" {
      restartIfChanged = false;
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        PLAYWRIGHT_BROWSERS_PATH = pkgs.playwright-driver.browsers;
        PLAYWRIGHT_DRIVER_PATH = pkgs.playwright-driver;
        PLAYWRIGHT_NODEJS_PATH = "${pkgs.nodejs}/bin/node";
      };
      serviceConfig = {
        WorkingDirectory = config.services.paperless.dataDir + "/.cache/downloader";
        Type = "oneshot";
        User = config.services.paperless.user;
        EnvironmentFile = config.age.secrets."downloader-creds-env".path;
        ExecStart = ''
          ${pkgs.downloader-go}/bin/downloader-go ${value.subcommand} --no-interaction --headless -o ${config.services.paperless.consumptionDir} -u ${value.var}_USERNAME -p ${value.var}_PASSWORD
        '';
      };
    }
  ) downloads;
}
