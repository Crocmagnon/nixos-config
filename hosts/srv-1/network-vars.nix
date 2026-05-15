{ lib, ... }:
{
  options.host.network = {
    ipv6 = lib.mkOption {
      type = lib.types.str;
      description = "IPv6 address assigned to this host.";
    };
    ipv6gw = lib.mkOption {
      type = lib.types.str;
      description = "IPv6 gateway address.";
    };
    interface = lib.mkOption {
      type = lib.types.str;
      description = "Primary network interface name.";
    };
    tailscaleIp = lib.mkOption {
      type = lib.types.str;
      description = "Tailscale IP used in Caddy `bind` directives to expose vhosts only on the Tailscale interface.";
    };
  };

  config.host.network = {
    ipv6 = "2001:41d0:700:114f::1";
    ipv6gw = "2001:41d0:0700:11ff:00ff:00ff:00ff:00ff";
    interface = "eno1";
    tailscaleIp = "100.108.113.85 [fd7a:115c:a1e0::2501:7166]";
  };
}
