{ config, ... }:
{
  # Public (pas d'`import internal`) : lecture et partage hors tailnet, liseuses sans Tailscale.
  # Readeck n'a pas d'option pour couper la connexion par mot de passe, et elle marche encore pour
  # les comptes rattachés à l'OIDC qui ont gardé leur ancien mot de passe : on la bloque ici, pour
  # tout le monde. GET /login reste (bouton Authelia), /login/oidc aussi. Secours : `readeck user` en SSH.
  services.caddy.virtualHosts."readeck.augendre.info".extraConfig = ''
    import common_headers
    @password_login {
      method POST
      path /login /login/
    }
    respond @password_login "Password login is disabled, sign in with Authelia." 403
    respond /login/mfa* 403
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
          # Crée le compte (rôle user) à la première connexion, ou rattache un compte existant de
          # même username ou email : vérifier qu'aucun compte local ne porte le nom d'un nouvel
          # utilisateur Authelia. Readeck réécrit aussi username et email à chaque connexion.
          provisioning = true;
        }
      ];
    };
  };

  # Le secret client OIDC est dans readeck-env : redémarrer quand il change (même principe qu'Authelia).
  systemd.services.readeck.restartTriggers = [
    (builtins.hashFile "sha256" config.age.secrets."readeck-env".file)
  ];
}
