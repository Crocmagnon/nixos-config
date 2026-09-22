{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.caddy.virtualHosts."odoo.srv-1.augendre.info".extraConfig = ''
    import common_headers
    import internal
    handle /websocket {
      reverse_proxy localhost:8072
    }
    handle {
      reverse_proxy localhost:8069
    }
  '';

  services.odoo = {
    enable = true;
    # Explicite : le défaut du module suit le stateVersion, et on ne veut pas qu'un bump
    # fasse changer Odoo de version majeure sans jouer les migrations.
    package = pkgs.odoo19;
    # domain reste null : Caddy fait le reverse proxy, pas le nginx du module.
    settings.options = {
      db_host = "ag56382-001.eu.clouddb.ovh.net";
      db_port = 35458;
      db_name = "odoo";
      db_user = "odoo";
      db_sslmode = "require";
      dbfilter = "^odoo$";
      # Odoo 19 écoute sur 0.0.0.0 par défaut (corrigé en 20.0). Sans ça il répond sur
      # l'IP publique de srv-1 et le bind Tailscale du snippet (internal) ne protège
      # plus rien.
      http_interface = "127.0.0.1";
      unaccent = true; # extension activée à la main dans l'espace client OVH
      db_maxconn = 4; # 6 processus × 4 = 24 connexions au pire, plafond OVH à 200
      workers = 3;
      limit_time_real = 120; # la base est distante, les requêtes traînent
      proxy_mode = true;
      # list_db = false est déjà le défaut du module.
      # db_password est volontairement absent : il arrive par PGPASSWORD depuis
      # l'EnvironmentFile, et psycopg2 laisse libpq le résoudre. Le mettre ici le
      # graverait en clair dans le store, world-readable, dans un dépôt public.
    };
  };

  # odoo19 tire python3.12-pypdf2-3.0.1 : six CVE, fork abandonné de pypdf, aucun
  # correctif amont possible. Exception assumée, cf.
  # docs/superpowers/specs/2026-09-22-odoo-srv-1-design.md. Épinglée à la version exacte
  # pour qu'elle échoue le jour où elle n'est plus nécessaire, au lieu de traîner.
  nixpkgs.config.permittedInsecurePackages = [ "python3.12-pypdf2-3.0.1" ];

  # Le module allume un PostgreSQL local en dur dont on n'a pas l'usage : la base est
  # chez OVH, et rien d'autre sur srv-1 ne veut de postgres local.
  services.postgresql.enable = lib.mkForce false;
  # Mais l'unité odoo met `config.services.postgresql.package` dans son PATH, pour le
  # pg_dump de la sauvegarde intégrée — et cette option n'a plus de valeur une fois le
  # service désactivé. On la pose sur la version qu'OVH fait tourner : pg_dump refuse de
  # sauvegarder un serveur plus récent que lui. Rien n'est installé pour autant, le
  # paquet sert seulement à peupler ce PATH.
  services.postgresql.package = pkgs.postgresql_17;
  systemd.services.odoo = {
    requires = lib.mkForce [ ]; # pointait sur postgresql.target, qui n'existe plus
    after = lib.mkForce [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig.EnvironmentFile = config.age.secrets."odoo-env".path;
  };
}
