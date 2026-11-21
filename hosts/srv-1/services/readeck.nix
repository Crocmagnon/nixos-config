{ config, ... }:
{
  services.caddy.virtualHosts."readeck.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:8006
  '';

  services.readeck = {
    enable = true;
    # READECK_SECRET_KEY et READECK_DATABASE_SOURCE (PostgreSQL OVH, cf. terraform-ovh).
    # La clé doit venir d'ici : le module réécrit config.toml à chaque démarrage,
    # une clé générée par Readeck y serait perdue (sessions et tokens invalidés).
    environmentFile = config.age.secrets."readeck-env".path;
    settings = {
      main.log_format = "text";
      server = {
        host = "127.0.0.1";
        port = 8006;
        base_url = "https://readeck.augendre.info";
      };
    };
  };
}
