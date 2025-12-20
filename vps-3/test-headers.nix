{...} : {
  virtualisation.oci-containers.containers = {
    test = {
      image = "python:3-slim";
      ports = ["127.0.0.1:9001:8080"];
      volumes = [
        "${./test_headers.py}:/app/app.py"
      ];
      cmd = ["python" "/app/app.py"];
    };
  };
}
