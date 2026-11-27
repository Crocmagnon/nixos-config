# calibre-web : bibliothèque Calibre de référence, gérée depuis l'UI (ajout, métadonnées), source
# de vérité sur le disque de srv-1 et sauvegardée par restic. Plus de copie depuis pCloud : un
# metadata.db (SQLite) dans un dossier synchronisé risquait la corruption. Ne jamais ouvrir cette
# bibliothèque depuis Calibre desktop par un partage réseau.
#
# Liseuses (KOReader, CrossPoint) : OPDS public sur books.srv-1-pub, voir plus bas. Elles
# téléchargent le fichier tel quel, la synchro de progression (kosync) les reconnaît par contenu.
{ config, ... }:
let
  libraryDir = "/var/lib/calibre-web/library";
  port = toString config.services.calibre-web.listen.port;
in
{
  services.calibre-web = {
    enable = true;
    listen.ip = "127.0.0.1";
    listen.port = 8005;
    options = {
      calibreLibrary = libraryDir;
      enableBookUploading = true;
      # Connexion par l'en-tête posé par le portail Authelia (`import sso` ci-dessous), ou par
      # Caddy pour l'OPDS public.
      reverseProxyAuth = {
        enable = true;
        header = "Remote-User";
      };
    };
  };

  services.caddy.virtualHosts."books.srv-1.augendre.info".extraConfig = ''
    import common_headers
    import internal
    # KOReader lit l'OPDS en auth Basic et ne sait pas passer le portail. Sans forward_auth,
    # rien ne retirerait un Remote-User forgé par le client : on le retire ici.
    handle /opds* {
      request_header -Remote-User
      reverse_proxy localhost:${port}
    }
    handle {
      import sso
      reverse_proxy localhost:${port}
    }
  '';

  # OPDS public pour les liseuses, sans Tailscale. Caddy vérifie l'identifiant, pas calibre-web :
  # en 0.6.26 son auth Basic de l'OPDS n'a pas de limite de tentatives (`# limiter.check()` dans
  # cps/usermanagement.py), ce qui exposerait tous les comptes, admin compris. Caddy n'accepte
  # que `liseuses` (hash bcrypt dans caddy-opds-env, OPDS_LISEUSES_HASH, cf. `caddy hash-password`)
  # puis se présente à calibre-web comme `gaugendre` : les liseuses voient ses étagères, son statut
  # « lu » et ses rubriques. Le mot de passe calibre-web n'est jamais vérifié depuis Internet, et
  # l'OPDS ne fait que lire et télécharger. calibre-web ne lit Remote-User que sans en-tête
  # Authorization, d'où son retrait.
  services.caddy.virtualHosts."books.srv-1-pub.augendre.info".extraConfig = ''
    import common_headers
    @not_opds not path /opds /opds/*
    respond @not_opds 404
    basic_auth {
      liseuses {$OPDS_LISEUSES_HASH}
    }
    reverse_proxy localhost:${port} {
      header_up -Authorization
      header_up Remote-User gaugendre
    }
  '';
}
