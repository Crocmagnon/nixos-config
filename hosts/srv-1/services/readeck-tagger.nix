# Tags unread Readeck bookmarks by theme with Claude, for offline filtering on KoReader.
# See Crocmagnon/readlist-tagger's docs/superpowers/specs/2026-11-21-readeck-support-design.md.
{ config, pkgs, ... }:
{
  systemd.timers.readeck-tagger = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "minutely";
      Persistent = true;
    };
  };

  systemd.services.readeck-tagger = {
    restartIfChanged = false;
    wants = [
      "network-online.target"
      "healthchecks@readeck-tagger:start.service"
    ];
    # Ordering only: wait for Readeck when both start together (boot), never start it.
    after = [
      "network-online.target"
      "readeck.service"
    ];
    onSuccess = [ "healthchecks@readeck-tagger:success.service" ];
    onFailure = [ "healthchecks@readeck-tagger:failure.service" ];
    path = [ pkgs.claude-code ];
    # claude writes its config under $HOME: the state directory.
    environment = {
      HOME = "/var/lib/readeck-tagger";
      READECK_URL = "http://localhost:8006";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.readeck-tagger}/bin/readeck-tagger";
      DynamicUser = true;
      StateDirectory = "readeck-tagger";
      WorkingDirectory = "/var/lib/readeck-tagger";
      # READECK_TOKEN, CLAUDE_CODE_OAUTH_TOKEN.
      EnvironmentFile = config.age.secrets."readeck-tagger-env".path;
    };
  };
}
