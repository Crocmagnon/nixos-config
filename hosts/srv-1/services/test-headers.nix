{
  virtualisation.oci-containers.containers = {
    test = {
      image = "python:3.15-slim@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928";
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
