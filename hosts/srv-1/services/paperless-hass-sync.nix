{ config, pkgs, ... }:
{
  systemd.timers.paperless-hass-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "minutely";
      Persistent = true;
    };
  };

  systemd.services.paperless-hass-sync = {
    restartIfChanged = false;
    wants = [
      "network-online.target"
      "healthchecks@paperless-hass-sync:start.service"
    ];
    after = [ "network-online.target" ];
    onSuccess = [ "healthchecks@paperless-hass-sync:success.service" ];
    onFailure = [ "healthchecks@paperless-hass-sync:failure.service" ];
    path = [ pkgs.openssh ];
    serviceConfig = {
      Type = "oneshot";
      User = "gaugendre";
      Group = "users";
      ExecStart = "${pkgs.rsync}/bin/rsync -rvz --remove-source-files hass:/share/paperless-consume/ ${config.services.paperless.consumptionDir}";
    };
  };
}
