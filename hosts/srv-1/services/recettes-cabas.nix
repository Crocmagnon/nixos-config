# Recettes & Cabas: the bridge between the planned recipes and Home Assistant, which holds the
# dashboard and the notifications. See downloader-go's
# docs/superpowers/specs/2026-10-11-recettes-cabas-home-assistant-design.md.
{
  pkgs,
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
in
{
  # Home Assistant reaches the bridge over Tailscale (refresh, apply).
  services.caddy.virtualHosts."recettes-cabas.srv-1.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:${toString apiPort}
  '';

  # The Recettes & Cabas bridge with Home Assistant: serves the API HA calls and pushes
  # each read of the site to HA's webhook. HA schedules the reads; the state directory
  # holds cookies.json and screenshots.
  systemd.services.recettes-cabas = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment.HOME = stateDir;
    serviceConfig = {
      ExecStart = "${pkgs.downloader-go}/bin/downloader-go --headless recettes-cabas serve --config ${configFile} --api-listen 127.0.0.1:${toString apiPort}";
      User = "recettes-cabas";
      DynamicUser = true;
      StateDirectory = "recettes-cabas";
      WorkingDirectory = stateDir;
      EnvironmentFile = config.age.secrets."recettes-cabas-env".path;
      Restart = "always";
      RestartSec = 30;
    };
  };
}
