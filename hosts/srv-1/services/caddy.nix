{
  pkgs,
  config,
  lib,
  ...
}:
let
  identity = import ../../../lib/identity.nix;
in
{
  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/ovh@v1.1.0" ];
      hash = "sha256-/xpTqYydmJEthBgGJ3uZ9FDF19dlvWs0h8XUf8KkS/M=";
    };
    email = identity.email;
    logFormat = ''
      format console
    '';
    globalConfig = ''
      dns ovh {
        endpoint ovh-eu
        application_key {$OVH_APP_KEY}
        application_secret {$OVH_APP_SECRET}
        consumer_key {$OVH_CONSUMER_KEY}
      }

      acme_dns ovh {
        endpoint ovh-eu
        application_key {$OVH_APP_KEY}
        application_secret {$OVH_APP_SECRET}
        consumer_key {$OVH_CONSUMER_KEY}
      }

      cert_issuer acme {
        profile shortlived
      }
    '';
    extraConfig = ''
      (common_headers) {
        header * -Server
        header * -X-Powered-By
        header * ?Strict-Transport-Security "max-age=0"
        header * ?Referrer-Policy "strict-origin-when-cross-origin"
        header * ?X-Content-Type-Options "nosniff"
      }

      (internal) {
        bind ${config.host.network.tailscaleIp}
        @blocked not client_ip private_ranges 2a01:e0a:325:a1c0::/64 fd7a:115c:a1e0::/48 100.0.0.0/8
        respond @blocked "Access denied" 403 {
          close
        }
        tls {
          resolvers 1.1.1.1 1.0.0.1
        }
      }
    '';
    virtualHosts = {
      "g4b.ovh".extraConfig = ''
        redir /carloni https://pizzacarloni.fr/wp-content/uploads/2024/06/MENU.pdf
        redir /mailcarrare https://framalistes.org/sympa/info/carrare
        redir /potain3 https://potain.augendre.info/potain03/
        redir /potain5 https://potain.augendre.info/potain05/
      '';

      "static.augendre.info".extraConfig = ''
        redir /potain3/ https://potain.augendre.info/potain03/
        redir /potain05/ https://potain.augendre.info/potain05/
        redir /doses/ https://doses.augendre.info/
        redir /qrcode-web/ https://qr.augendre.info/
      '';

      "augendre.info".extraConfig = ''
        import common_headers
        respond * 200
      '';

      "mariage.augendre.info".extraConfig = ''
        import common_headers
        redir https://e.pcloud.link/publink/show?code=kZAG2qZWQWJbKTUgJ0DjeFn0cmcDhr48S2V
      '';

      "mail.augendre.info".extraConfig = ''
        import common_headers
        redir https://webmail.migadu.com permanent
      '';

      "cv-gabriel.augendre.info".extraConfig = ''
        import common_headers
        redir https://e.pcloud.link/publink/show?code=XZVYidZt0r7H6wbWThqi1xlWOQnCjHKfcrV permanent
      '';

      "git.augendre.info".extraConfig = ''
        redir https://codeberg.org/Crocmagnon
      '';
    };
  };
  systemd.services.caddy = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    serviceConfig.EnvironmentFile = [ config.age.secrets."ovh-keys".path ];
  };
}
