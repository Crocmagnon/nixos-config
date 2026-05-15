{ ... }:
{
  # workarounds for uv python
  programs.nix-ld = {
    enable = true;
  };
  environment.etc.certfile = {
    source = "/etc/ssl/certs/ca-bundle.crt";
    target = "ssl/cert.pem";
  };
}
