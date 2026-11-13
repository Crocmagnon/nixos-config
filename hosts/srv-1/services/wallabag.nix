{ config, ... }:
{
  services.caddy.virtualHosts."wallabag.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:8002
  '';

  virtualisation.oci-containers.containers = {
    wallabag = {
      image = "wallabag/wallabag:2.6.16@sha256:5f758bc85c416f695c05099ba58f58ae7ffa1e7e6a1ba3ff865a51e3c18399b7";
      environmentFiles = [ config.age.secrets."wallabag-env".path ];
      volumes = [
        "images:/var/www/wallabag/web/assets/images"
      ];
      ports = [ "127.0.0.1:8002:80" ];
    };
  };
}
