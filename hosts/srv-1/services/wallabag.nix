{ config, ... }:
{
  services.caddy.virtualHosts."wallabag.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:8002
  '';

  virtualisation.oci-containers.containers = {
    wallabag = {
      image = "wallabag/wallabag:2.6.17@sha256:9055d92d6e7973abea2d902ecb5459f6063fce05595eaef37f6750e49ff8cdee";
      environmentFiles = [ config.age.secrets."wallabag-env".path ];
      volumes = [
        "images:/var/www/wallabag/web/assets/images"
      ];
      ports = [ "127.0.0.1:8002:80" ];
    };
  };
}
