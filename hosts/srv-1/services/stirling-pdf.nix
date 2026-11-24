{
  services.stirling-pdf = {
    enable = true;
    # TODO(26.11): stirling-pdf 3.1 marks its default build unfree (proprietary login and extras).
    # Switch to the MIT build: `package = pkgs.stirling-pdf-free;`. It has no built-in login,
    # which changes nothing here: login is disabled below and the vhost is behind the Authelia portal.
    environment = {
      # Spring Boot : SERVER_ADDRESS (SERVER_HOST était ignoré, Stirling écoutait sur tout le tailnet
      # sans passer par le portail).
      SERVER_ADDRESS = "127.0.0.1";
      # SERVER_SSL_ENABLED = "false";
      SERVER_PORT = 8004;
      SECURITY_ENABLELOGIN = "false";
      SYSTEM_DEFAULTLOCALE = "fr-FR";
      SYSTEM_MAXFILESIZE = "2000";
    };
  };

  services.caddy.virtualHosts."pdf.srv-1.augendre.info".extraConfig = ''
    import common_headers
    import internal
    import sso
    reverse_proxy localhost:8004
  '';
}
