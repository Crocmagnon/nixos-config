{ lib, config, ... }:
let
  net = config.host.network;
in
{
  services.openssh.enable = true;

  networking = {
    hostName = "srv-1";
    enableIPv6 = true;
    useNetworkd = lib.mkDefault true;
    firewall = {
      allowedTCPPorts = [
        80
        443
      ];
      trustedInterfaces = [ "tailscale0" ];
    };
    interfaces."${net.interface}" = {
      useDHCP = true;
      ipv6 = {
        addresses = [
          {
            address = net.ipv6;
            prefixLength = 128;
          }
        ];
        routes = [
          {
            address = net.ipv6gw;
            prefixLength = 64;
          }
        ];
      };
    };
    defaultGateway6 = {
      address = net.ipv6gw;
      interface = net.interface;
    };
  };
  services.fail2ban.enable = true;
}
