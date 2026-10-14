# Recettes & Cabas: weekly Telegram recap of the planned recipes, and the bot that changes
# the selection. See downloader-go's docs/superpowers/specs/2026-10-11-recettes-cabas-design.md.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  configFile = pkgs.writeText "recettes-cabas.json" (
    builtins.toJSON {
      excludeOptions = [
        "château"
        "domaine"
        "vin"
        "rosé"
        "IGP"
        "AOC"
      ];
      flags = [
        {
          emoji = "🍄";
          keywords = [
            "champignon"
            "cèpe"
            "girolle"
            "shiitake"
            "pleurote"
            "morille"
            "trompette"
          ];
        }
        {
          emoji = "🥗";
          keywords = [
            "salade"
            "laitue"
            "mâche"
            "roquette"
            "mesclun"
            "batavia"
            "sucrine"
            "romaine"
            "jeunes pousses"
          ];
        }
      ];
    }
  );
  stateDir = "/var/lib/recettes-cabas";
  apiPort = 8789;
  cmd = sub: "${pkgs.downloader-go}/bin/downloader-go --headless recettes-cabas ${sub} --config ${configFile}";
  # Both units share the dynamic user (same name) and its state directory: cookies.json,
  # prefs.json (/affichage) and screenshots.
  common = {
    after = [ "network-online.target" ];
    environment.HOME = stateDir;
    serviceConfig = {
      User = "recettes-cabas";
      DynamicUser = true;
      StateDirectory = "recettes-cabas";
      WorkingDirectory = stateDir;
      EnvironmentFile = config.age.secrets."recettes-cabas-env".path;
    };
  };
in
{
  # Home Assistant reaches the bot over Tailscale (refresh, apply).
  services.caddy.virtualHosts."recettes-cabas.srv-1.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:${toString apiPort}
  '';

  systemd.timers.recettes-cabas-recap = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Wed 18:00";
      Persistent = true;
    };
  };

  systemd.services.recettes-cabas-recap = lib.recursiveUpdate common {
    restartIfChanged = false;
    wants = [
      "network-online.target"
      "healthchecks@recettes-cabas-recap:start.service"
    ];
    onSuccess = [ "healthchecks@recettes-cabas-recap:success.service" ];
    onFailure = [ "healthchecks@recettes-cabas-recap:failure.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = cmd "recap";
    };
  };

  # Only one process may poll a bot token: Telegram answers 409 Conflict to a second one.
  systemd.services.recettes-cabas-bot = lib.recursiveUpdate common {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      # The API Home Assistant calls, behind the internal vhost above.
      ExecStart = "${cmd "bot"} --api-listen 127.0.0.1:${toString apiPort}";
      Restart = "always";
      RestartSec = 30;
    };
  };
}
