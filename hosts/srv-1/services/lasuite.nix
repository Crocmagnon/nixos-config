{ config, ... }:
{
  services.lasuite-meet = {
    enable = true;
    domain = "visio.g4b.ovh";
    livekit.openFirewall = true;
    livekit.keyFile = config.age.secrets."livekit".path;
    redis.createLocally = true;
    environmentFile = config.age.secrets."lasuite-meet".path;
    enableNginx = false;
    settings = {
      DJANGO_ALLOWED_HOSTS = "localhost,127.0.0.1,${config.services.lasuite-meet.domain}";
      LIVEKIT_API_URL = "https://${config.services.lasuite-meet.domain}/livekit";
    };
    bind = "127.0.0.1:8080";
  };

  services.caddy.virtualHosts."${config.services.lasuite-meet.domain}".extraConfig = ''
    reverse_proxy ${config.services.lasuite-meet.bind}
  '';
}
