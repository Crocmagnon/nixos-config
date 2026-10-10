# Agent OpenClaw — voir docs/superpowers/specs/2026-10-10-openclaw-srv-1-design.md.
#
# L'agent lit des pages web arbitraires (injection de prompt) : on borne ce qu'il atteint.
# Son identité est son sous-réseau podman ; depuis lui, seuls Internet et Caddy:443 passent.
# Caddy refuse ensuite ce sous-réseau sur tout vhost `internal` (snippet dans caddy.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  net = config.host.network;
  subnet = net.agentSubnet;
  gateway = "10.89.42.1";
  # tailscaleIp est au format Caddy ("v4 [v6]") ; le réseau podman n'a que de l'IPv4.
  tailscaleV4 = builtins.head (lib.splitString " " net.tailscaleIp);
  ipt = "${pkgs.iptables}/bin/iptables";
in
{
  # oci-containers ne gère pas les réseaux podman.
  systemd.services.podman-network-openclaw = {
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-openclaw.service" ];
    path = [ config.virtualisation.podman.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman network exists openclaw \
        || podman network create --subnet ${subnet} --gateway ${gateway} openclaw
    '';
  };

  # Table mangle et non filter : netavark insère ses propres règles dans filter/nat à
  # chaque démarrage de conteneur, et mangle PREROUTING passe avant le routage, donc
  # avant INPUT comme avant FORWARD. DROP et non REJECT (interdit dans mangle).
  # Seules les connexions NEW sont filtrées : les réponses aux connexions entrantes
  # (Caddy → port publié) doivent passer.
  networking.firewall.extraCommands = ''
    ${ipt} -t mangle -N openclaw-egress 2>/dev/null || ${ipt} -t mangle -F openclaw-egress
    ${ipt} -t mangle -C PREROUTING -s ${subnet} -j openclaw-egress 2>/dev/null \
      || ${ipt} -t mangle -I PREROUTING -s ${subnet} -j openclaw-egress
    ${ipt} -t mangle -A openclaw-egress -m conntrack ! --ctstate NEW -j RETURN
    ${ipt} -t mangle -A openclaw-egress -d ${gateway} -p udp --dport 53 -j RETURN
    ${ipt} -t mangle -A openclaw-egress -d ${gateway} -p tcp --dport 53 -j RETURN
    ${ipt} -t mangle -A openclaw-egress -d ${tailscaleV4} -p tcp --dport 443 -j RETURN
    # Toute adresse de srv-1 (publique, tailscale, passerelle podman…) sauf ci-dessus.
    ${ipt} -t mangle -A openclaw-egress -m addrtype --dst-type LOCAL -j DROP
    ${ipt} -t mangle -A openclaw-egress -d ${subnet} -j RETURN
    for dst in 100.64.0.0/10 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16; do
      ${ipt} -t mangle -A openclaw-egress -d "$dst" -j DROP
    done
  '';
  networking.firewall.extraStopCommands = ''
    ${ipt} -t mangle -D PREROUTING -s ${subnet} -j openclaw-egress 2>/dev/null || true
    ${ipt} -t mangle -F openclaw-egress 2>/dev/null || true
    ${ipt} -t mangle -X openclaw-egress 2>/dev/null || true
  '';
}
