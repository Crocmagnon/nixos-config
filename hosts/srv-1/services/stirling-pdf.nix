{
  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_HOST = "127.0.0.1";
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
    reverse_proxy localhost:8004
  '';
}
