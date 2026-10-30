{ config, ... }:
{
  services.caddy.virtualHosts."wallabag.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:8002
  '';

  virtualisation.oci-containers.containers = {
    wallabag = {
      image = "wallabag/wallabag:2.6.15@sha256:d54d48f58503505192c8c283f575d7b90e116ae43ec90e54afadf7d279bfe106";
      environmentFiles = [ config.age.secrets."wallabag-env".path ];
      volumes = [
        "images:/var/www/wallabag/web/assets/images"
      ];
      ports = [ "127.0.0.1:8002:80" ];
    };
  };
}
