{
  virtualisation.oci-containers.containers = {
    test = {
      image = "python:3.15-slim@sha256:94d3426f1def7db4a106a232ac121bfd975393e5dfd40a619b955fae45fe7913";
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
