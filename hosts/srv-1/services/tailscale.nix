{ config, ... }:
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    authKeyFile = config.age.secrets."tailscale-auth-key".path;
    authKeyParameters.ephemeral = false;
    authKeyParameters.preauthorized = true;
    extraUpFlags = [
      "--ssh"
      "--advertise-exit-node"
      "--accept-dns"
      "--accept-routes"
      "--advertise-tags=tag:nix,tag:home"
    ];
  };
}
