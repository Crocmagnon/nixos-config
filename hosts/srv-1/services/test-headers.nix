{
  virtualisation.oci-containers.containers = {
    test = {
      image = "python:3.15-slim@sha256:63bb298d2b7b88f176f51b5189f54ce6535c997682ea70885d2132f5d473a8a5";
      ports = [ "127.0.0.1:9001:8080" ];
      volumes = [
        "${./test_headers.py}:/app/app.py"
      ];
      cmd = [
        "python"
        "/app/app.py"
      ];
    };
  };

  services.caddy.virtualHosts."test.augendre.info".extraConfig = ''
    import common_headers
    import internal
    redir localhost:9001
  '';

}
