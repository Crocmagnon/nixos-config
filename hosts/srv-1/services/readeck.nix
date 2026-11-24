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
      # Connexion OIDC via Authelia (authelia.nix). Le secret client vient de readeck-env
      # (READECK_AUTH_OIDC_PROVIDERS_0_CLIENT_SECRET : l'index 0 fusionne avec ce provider).
      auth.oidc.providers = [
        {
          name = "Authelia";
          url = "https://auth.srv-1.augendre.info";
          client_id = "readeck";
          # Readeck réécrit le groupe du compte à chaque connexion : sans ça, admin → user.
          groups = [
            [
              "admins"
              "admin"
            ]
          ];
          # Rattache le compte existant (username ou email) sans en créer de nouveau.
          provisioning = false;
        }
      ];
    };
  };
}
