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

  version = "2026.9.9";
  stateDir = "/var/lib/openclaw";
  # Utilisateur `node` de l'image.
  uid = 1000;
  # Sans remappage, `node` (1000) serait l'UID 1000 de l'hôte, gaugendre, qui a sudo
  # sans mot de passe : une évasion du conteneur y atterrirait. On décale tout l'espace
  # d'UID du conteneur dans une plage que personne n'utilise sur l'hôte.
  uidBase = 200000;
  hostUid = toString (uidBase + uid);
  origin = "https://ai.augendre.info";
  models = [
    "Qwen3.5-397B-A17B"
    "gpt-oss-120b"
  ];
  # Les secrets sont des références à l'environnement du conteneur (environmentFiles),
  # résolues par OpenClaw : le store Nix n'en voit aucun. SecretRef là où le schéma
  # l'accepte (le doctor tient une chaîne "${VAR}" pour un secret en clair), sinon "${VAR}".
  envRef = id: {
    source = "env";
    provider = "default";
    inherit id;
  };
  settings = {
    gateway = {
      mode = "local";
      port = 18789;
      # "lan" = 0.0.0.0 dans le conteneur ; côté hôte, le port n'est publié que sur 127.0.0.1.
      bind = "lan";
      publicOrigin = origin;
      auth = {
        mode = "token";
        token = envRef "OPENCLAW_GATEWAY_TOKEN";
      };
      # Caddy arrive par le port publié : la Gateway voit la passerelle podman.
      trustedProxies = [ gateway ];
      controlUi.allowedOrigins = [ origin ];
    };
    models = {
      mode = "merge";
      providers.ovhcloud = {
        baseUrl = "https://oai.endpoints.kepler.ai.cloud.ovh.net/v1";
        apiKey = envRef "OVH_AI_ENDPOINTS_API_KEY";
        api = "openai-completions";
        models = map (id: {
          inherit id;
          name = id;
          compat.supportsStore = false;
        }) models;
      };
    };
    agents.defaults = {
      model = {
        primary = "ovhcloud/${builtins.elemAt models 0}";
        fallbacks = [ "ovhcloud/${builtins.elemAt models 1}" ];
      };
      models = lib.genAttrs (map (id: "ovhcloud/${id}") models) (_: { });
    };
    channels.telegram = {
      enabled = true;
      botToken = envRef "TELEGRAM_BOT_TOKEN";
      dmPolicy = "allowlist";
      # L'ID n'est pas un secret mais le repo est public.
      allowFrom = [ "tg:\${TELEGRAM_OWNER_ID}" ];
      groupPolicy = "disabled";
    };
    # Les commandes réservées au propriétaire (/config…) n'acceptent que lui.
    commands.ownerAllowFrom = [ "telegram:\${TELEGRAM_OWNER_ID}" ];
    # L'agent n'écrit que dans la conversation en cours.
    tools.message.crossContext = {
      allowAcrossProviders = false;
      allowWithinProvider = false;
    };
    # Liste fermée : seuls ces plugins livrés avec l'image se chargent, donc rien
    # d'installé depuis ClawHub. Le navigateur et Telegram sont eux-mêmes des plugins.
    plugins.allow = [
      "browser"
      "telegram"
      "memory-core"
      "device-pair"
      "web-readability"
      "document-extract"
    ];
    browser = {
      enabled = true;
      headless = true;
      # Le sandbox de Chromium est une vraie protection contre une page piégée :
      # ne le couper que s'il est prouvé qu'il ne démarre pas.
      noSandbox = false;
      defaultProfile = "openclaw";
      profiles.openclaw.cdpPort = 18800;
      # Aucune extension Chrome ni client CDP externe : pas besoin de l'ancienne auth.
      extensionRelay.allowLegacyAuth = false;
    };
    # Les mises à jour passent par le tag de l'image, pas par la Gateway.
    update.checkOnStart = false;
  };
  configFile = pkgs.writeText "openclaw.json" (builtins.toJSON settings);
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

  systemd.tmpfiles.rules = [ "d ${stateDir} 0700 ${hostUid} ${hostUid} - -" ];

  virtualisation.oci-containers.containers.openclaw = {
    image = "ghcr.io/openclaw/openclaw:${version}-browser";
    volumes = [ "${stateDir}:/home/node/.openclaw" ];
    environmentFiles = [ config.age.secrets."openclaw-env".path ];
    ports = [ "127.0.0.1:18789:18789" ];
    networks = [ "openclaw" ];
    extraOptions = [
      "--uidmap=0:${toString uidBase}:65536"
      "--gidmap=0:${toString uidBase}:65536"
    ];
  };

  systemd.services.podman-openclaw = {
    requires = [ "podman-network-openclaw.service" ];
    after = [ "podman-network-openclaw.service" ];
    # La Gateway réécrit son fichier (Control UI, `config set`) et refuse un symlink :
    # on recopie la version Nix à chaque démarrage. Un changement fait à chaud est donc
    # perdu au redémarrage — voulu, la config vit dans ce fichier.
    preStart = ''
      install -m 0600 -o ${hostUid} -g ${hostUid} ${configFile} ${stateDir}/openclaw.json
    '';
  };

  services.caddy.virtualHosts."ai.augendre.info".extraConfig = ''
    import common_headers
    import internal
    reverse_proxy localhost:18789
  '';
}
