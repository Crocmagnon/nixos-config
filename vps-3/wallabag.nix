{ config, ...} : {
  virtualisation.oci-containers = {
    containers = {
      wallabag = {
        image = "wallabag/wallabag:latest";
        environmentFiles = [ config.age.secrets."wallabag-env".path ];
        volumes = [
          "images:/var/www/wallabag/web/assets/images"
        ];
        ports = ["127.0.0.1:8002:80"];
        labels = {
          "com.centurylinklabs.watchtower.lifecycle.post-update" = "/var/www/wallabag/bin/console doctrine:migrations:migrate --env=prod --no-interaction";
          "com.centurylinklabs.watchtower.lifecycle.post-update-timeout" = "600";
        };
      };
    };
  };
}
