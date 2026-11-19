# Tags unread Wallabag articles by theme with Claude, for offline filtering on KoReader.
# See Crocmagnon/wallabag-tagger's docs/superpowers/specs/2026-11-19-wallabag-tagger-design.md.
{ config, pkgs, ... }:
{
  systemd.timers.wallabag-tagger = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "minutely";
      Persistent = true;
    };
  };

  systemd.services.wallabag-tagger = {
    restartIfChanged = false;
    wants = [
      "network-online.target"
      "healthchecks@wallabag-tagger:start.service"
    ];
    after = [ "network-online.target" ];
    onSuccess = [ "healthchecks@wallabag-tagger:success.service" ];
    onFailure = [ "healthchecks@wallabag-tagger:failure.service" ];
    path = [ pkgs.claude-code ];
    # claude writes its config under $HOME: the state directory.
    environment = {
      HOME = "/var/lib/wallabag-tagger";
      WALLABAG_URL = "http://localhost:8002";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.wallabag-tagger}/bin/wallabag-tagger";
      DynamicUser = true;
      StateDirectory = "wallabag-tagger";
      # WALLABAG_CLIENT_ID, WALLABAG_CLIENT_SECRET, WALLABAG_USERNAME, WALLABAG_PASSWORD,
      # CLAUDE_CODE_OAUTH_TOKEN.
      EnvironmentFile = config.age.secrets."wallabag-tagger-env".path;
    };
  };
}
