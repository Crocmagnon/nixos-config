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
  # TODO(26.11): fail2ban 1.1.0 -> 1.1.1 has a few breaking changes
  # (https://github.com/fail2ban/fail2ban/blob/1.1.1/ChangeLog); defaults only here, so just check
  # `journalctl -u fail2ban` after the upgrade.
  services.fail2ban.enable = true;
}
