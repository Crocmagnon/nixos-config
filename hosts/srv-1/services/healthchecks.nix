{
  lib,
  pkgs,
  config,
  ...
}:
{
  # https://github.com/VTimofeenko/monorepo-machine-config/blob/668bb866e1925df9e5aeeed029b719fc1c1572f7/nixosModules/services/gitea/bkp.nix#L31
  systemd.services."healthchecks@" = {
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
              # Last 100 kB only: hc-ping.com keeps no more, and a whole nixos-upgrade log
              # (several MB) passed to curl as one argument hit "Argument list too long".
              LOGS=$(journalctl --no-pager -u "$MONITOR_UNIT" --since "$LAST_TIMESTAMP" | tail -c 100000)

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
}
