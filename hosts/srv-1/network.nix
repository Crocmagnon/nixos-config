{ lib, network, ... }:
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
    interfaces."${network.interface}" = {
      useDHCP = true;
      ipv6 = {
        addresses = [
          {
            address = network.ipv6;
            prefixLength = 128;
          }
        ];
        routes = [
          {
            address = network.ipv6gw;
            prefixLength = 64;
          }
        ];
      };
    };
    defaultGateway6 = {
      address = network.ipv6gw;
      interface = network.interface;
    };
  };
  services.fail2ban.enable = true;
}
