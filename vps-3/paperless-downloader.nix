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

  systemd.services =
    lib.mapAttrs' (
      name: value:
      lib.nameValuePair "download-${name}" {
        restartIfChanged = false;
        wants = [
          "network-online.target"
          "healthchecks@download-${name}:start.service"
        ];
        after = [ "network-online.target" ];
        onSuccess = [ "healthchecks@download-${name}:success.service" ];
        onFailure = [ "healthchecks@download-${name}:failure.service" ];
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
    ) downloads
    // {
      # https://github.com/VTimofeenko/monorepo-machine-config/blob/668bb866e1925df9e5aeeed029b719fc1c1572f7/nixosModules/services/gitea/bkp.nix#L31
      "healthchecks@" = {
        serviceConfig.ExecStart =
          let
            ping-hc = pkgs.writeShellApplication {
              name = "ping-hc";
              runtimeInputs = [
                pkgs.curl
                pkgs.hostname
              ];
              text = ''
                # If I ever want to debug this:
                # env
                # set -x

                API_KEY=$(cat ${config.age.secrets."healthchecks-api-key".path})

                # Source: https://passbe.com/2022/healthchecks-io-systemd-checks/
                # Parse the template variable into actions
                IFS=:
                read -r SLUG ACTION <<< "$1"

                # Remove "@localhost" from the UUID
                SLUG="''${SLUG%%@localhost}"

                if [ "$ACTION" = "start" ]; then
                  LOGS=""
                  EXIT_CODE="start?create=1"
                else
                  # Get logs of last invocation
                  # Source:
                  # https://serverfault.com/questions/768901/is-there-a-way-to-make-journalctl-show-logs-from-the-last-time-foo-service-ran
                  # Slight tweak -- needs InactiveExitTimestamp ?
                  LAST_TIMESTAMP=$(systemctl show --property InactiveExitTimestamp --value "$MONITOR_UNIT")
                  LOGS=$(journalctl --no-pager -u "$MONITOR_UNIT" --since "$LAST_TIMESTAMP")

                  # This will be 1 in case of error
                  # Healthchecks supports "fail" or 1 for this:
                  # https://healthchecks.srv.vtimofeenko.com/docs/signaling_failures/
                  EXIT_CODE=$MONITOR_EXIT_STATUS
                fi

                curl \
                  --fail `#fail fast on server errors` \
                  --show-error --silent `#show error <=> it fails` \
                  --max-time 10 \
                  --retry 3 \
                  --data-raw "$LOGS" \
                  -A "$(hostname)" \
                  "https://hc-ping.com/$API_KEY/$SLUG/$EXIT_CODE"
              '';
            };
          in
          "${lib.getExe ping-hc} %i";
      };
    };
}
