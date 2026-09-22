{ pkgs, ... }:
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
      db_name = "odoo";
      # Odoo 19 écoute sur 0.0.0.0 par défaut (corrigé en 20.0). Sans ça il répond sur
      # l'IP publique de srv-1 et le bind Tailscale du snippet (internal) ne protège
      # plus rien.
      http_interface = "127.0.0.1";
      unaccent = true;
      # max_connections vaut 100 sur le postgres local ; 6 processus Odoo (3 HTTP,
      # 2 cron, 1 evented) × 8 = 48, on reste au large.
      db_maxconn = 8;
      workers = 3;
      proxy_mode = true;
      # Pas de db_host/db_port/db_user/db_password : socket unix locale, authentification
      # peer, l'utilisateur système odoo correspond au rôle odoo que le module crée.
      # Pas de dbfilter non plus : il force Odoo à énumérer pg_database au lieu de
      # prendre son raccourci « db_name est la liste des bases exposées ».
      # Pas de limit_time_real : 120 s est le défaut d'Odoo, et il suffit largement une
      # fois la base locale — c'est lui qui avait tué l'installation des 48 modules
      # quand chaque requête coûtait 12 ms d'aller-retour vers OVH.
    };
  };

  # Épinglé pour la même raison qu'odoo19 : le défaut suit le stateVersion, et changer
  # de version majeure de PostgreSQL ne se fait pas par un simple rebuild — il faut
  # passer pg_upgrade sur le répertoire de données.
  services.postgresql.package = pkgs.postgresql_17;

  # odoo19 tire python3.12-pypdf2-3.0.1 : six CVE, fork abandonné de pypdf, aucun
  # correctif amont possible. Exception assumée, cf.
  # docs/superpowers/specs/2026-09-22-odoo-srv-1-design.md. Épinglée à la version exacte
  # pour qu'elle échoue le jour où elle n'est plus nécessaire, au lieu de traîner.
  nixpkgs.config.permittedInsecurePackages = [ "python3.12-pypdf2-3.0.1" ];
}
