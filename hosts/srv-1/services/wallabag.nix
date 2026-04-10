{ config, ... }:
{
  services.caddy.virtualHosts."wallabag.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:8002
  '';

  virtualisation.oci-containers.containers = {
    wallabag = {
      image = "wallabag/wallabag:latest";
      environmentFiles = [ config.age.secrets."wallabag-env".path ];
      volumes = [
        "images:/var/www/wallabag/web/assets/images"
      ];
      ports = [ "127.0.0.1:8002:80" ];
    };
  };
}
