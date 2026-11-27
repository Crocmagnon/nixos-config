# Serveur KOSync (progression de lecture des liseuses : Kobo/KOReader, Xteink X4 Pro/CrossPoint),
# public sur kosync.srv-1-pub.augendre.info.
#
# Pas le module NixOS du projet : il ouvre son port dans le pare-feu public. On reprend seulement
# son paquet, et le service écoute sur 127.0.0.1 derrière Caddy.
#
# Comptes : l'inscription reste active côté application mais /users/create n'est pas publié.
# Créer un compte depuis srv-1 (le mot de passe s'envoie haché en MD5, comme le fait KOSync) :
#   curl -X POST http://127.0.0.1:8010/users/create -H 'Content-Type: application/json' \
#     -d "{\"username\":\"<nom>\",\"password\":\"$(printf %s '<mdp>' | md5sum | cut -d' ' -f1)\"}"
# Base SQLite dans /var/lib/private/crosspoint-sync (DynamicUser), sauvegardée par restic.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  port = 8010;
  crosspoint-sync = pkgs.callPackage "${inputs.crosspoint-sync}/nix/package.nix" { };
in
{
  systemd.services.crosspoint-sync = {
    description = "crosspoint-sync (serveur KOSync)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = {
      LISTEN_ADDRESS = "127.0.0.1";
      PORT = toString port;
      DATABASE_PATH = "/var/lib/crosspoint-sync/crosspoint.db";
      # Caddy remplace X-Forwarded-For par l'IP du client : limite d'inscription par IP fiable.
      TRUST_PROXY = "true";
    };
    serviceConfig = {
      ExecStart = lib.getExe crosspoint-sync;
      DynamicUser = true;
      StateDirectory = "crosspoint-sync";
      Restart = "on-failure";
    };
  };

  # Public, mais seulement le protocole KOSync : ni l'app web, ni les connecteurs, ni l'inscription.
  services.caddy.virtualHosts."kosync.srv-1-pub.augendre.info".extraConfig = ''
    import common_headers
    @not_kosync not path /users/auth /syncs/progress /syncs/progress/*
    respond @not_kosync 404
    reverse_proxy 127.0.0.1:${toString port}
  '';
}
