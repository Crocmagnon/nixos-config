# OpenClaw sur srv-1 — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** un assistant OpenClaw sur srv-1, joignable par Telegram et par `https://ai.augendre.info` (tailnet seulement), modèles AI Endpoints OVHcloud, enfermé dans un conteneur podman dont la sortie est filtrée.

**Architecture:** un réseau podman dédié (`10.89.42.0/24`) est l'identité de l'agent. Des règles iptables (table `mangle`) bornent sa sortie à Internet + Caddy:443 ; Caddy refuse ce sous-réseau sur tout vhost `internal`, sauf ceux passés en `internal_agent`. Le conteneur OpenClaw officiel tourne sur ce réseau, configuré par un `openclaw.json` généré par Nix et recopié dans l'état à chaque démarrage.

**Tech Stack:** NixOS (flake), `virtualisation.oci-containers` (podman), Caddy, agenix, restic, OpenClaw `ghcr.io/openclaw/openclaw:<version>-browser`, OVHcloud AI Endpoints.

**Spec:** `docs/superpowers/specs/2026-10-10-openclaw-srv-1-design.md`

## Global Constraints

- Sous-réseau de l'agent : `10.89.42.0/24`, passerelle `10.89.42.1`, réseau podman `openclaw`.
- Domaine : `ai.augendre.info` (DNS déjà publié, `terraform-ovh` commit `1970b58`), vhost `import internal`.
- Modèles : primaire `Qwen3.5-397B-A17B`, fallback `gpt-oss-120b`, `baseUrl https://oai.endpoints.kepler.ai.cloud.ovh.net/v1`, `api: "openai-completions"`, `compat.supportsStore = false`. Identifiants exacts relevés sur `/v1/models`.
- Image pinnée sur une version précise, jamais `latest`.
- Aucun montage hôte hors `/var/lib/openclaw` ; aucun socket podman.
- Secrets : jamais déchiffrés, affichés ou modifiés par l'agent d'implémentation. L'utilisateur fait lui-même `agenix -e`. Aucune valeur secrète ni l'ID Telegram de l'utilisateur dans le repo (public) : variables d'environnement seulement.
- Pas de nix sur les desktops : on build et on bascule **sur srv-1**, qui tire `main` depuis Codeberg (`mise run srv-1`). Donc chaque déploiement = commit + push sur `main`, **chacun soumis au go de l'utilisateur**.
- Le hook pre-commit lance `nixfmt` (`language: system`). S'il n'est pas installé localement, s'arrêter et demander à l'utilisateur ; ne pas contourner avec `--no-verify`.
- Les commentaires de code suivent ceux du repo : en français, ils disent *pourquoi*.

## Review Focus

1. **Les règles d'egress disparaissent après un `systemctl restart firewall`, un reboot ou un redémarrage de podman** — l'agent doit rester enfermé dans tous ces cas. Test Task 1, step 9.
2. **Les réponses aux connexions entrantes ne doivent pas être coupées** : Caddy → conteneur passe par le port publié ; si la règle `ctstate NEW` manque, le Control UI casse. Test Task 2, step 10.
3. **Un vhost `internal` créé plus tard reste fermé à l'agent par défaut** (c'est le snippet par défaut qui bloque). Test Task 1, step 8 (`sonarr`).
4. **Le redémarrage écrase les changements de config faits à chaud** (`openclaw config set`, Control UI) : comportement voulu, mais les crons et l'appairage ne doivent **pas** être perdus. Test Task 4, step 3.
5. **Le fallback doit s'enclencher sur une vraie erreur du primaire**, pas seulement sur une config invalide. Test Task 2, step 12.
6. **Une évasion du conteneur ne doit pas atterrir sur l'UID 1000 de l'hôte** (`gaugendre`, sudo sans mot de passe) : sans remappage, l'utilisateur `node` de l'image *est* l'UID 1000 de l'hôte. Test Task 2, step 7.

---

## File Structure

| Fichier | Rôle |
|---|---|
| `hosts/srv-1/network-vars.nix` | + option `host.network.agentSubnet`, lue par Caddy et par `openclaw.nix` |
| `hosts/srv-1/services/caddy.nix` | snippets `internal_base` / `internal` / `internal_agent` |
| `hosts/srv-1/services/{miniflux,wallabag,paperless,servarr}.nix` | leurs vhosts ouverts à l'agent passent à `internal_agent` (jellyfin seul dans servarr) |
| `hosts/srv-1/services/openclaw.nix` (nouveau) | réseau podman, egress, conteneur, config, vhost `ai` |
| `hosts/srv-1/services/default.nix` | import de `openclaw.nix` |
| `hosts/srv-1/age/secrets.nix` | règle `openclaw-env.age` |
| `hosts/srv-1/services/restic.nix` | sauvegarde de `/var/lib/openclaw` |
| `CLAUDE.md` | section Caddy (`internal_agent`) et notes OpenClaw |

---

### Task 1 : identité réseau de l'agent (réseau podman, egress, Caddy)

Livrable testable seul, sans OpenClaw : un conteneur jetable sur le réseau `openclaw` atteint Internet et les quatre vhosts ouverts, et rien d'autre.

**Files:**
- Modify: `hosts/srv-1/network-vars.nix`
- Modify: `hosts/srv-1/services/caddy.nix:46-56` (snippet `(internal)`)
- Modify: `hosts/srv-1/services/miniflux.nix:5`, `wallabag.nix:5`, `paperless.nix:10`, `servarr.nix:102` (jellyfin seulement)
- Create: `hosts/srv-1/services/openclaw.nix`
- Modify: `hosts/srv-1/services/default.nix`
- Modify: `CLAUDE.md` (section « Caddy Internal Access (srv-1) »)

**Interfaces:**
- Produces: `config.host.network.agentSubnet` (`"10.89.42.0/24"`) ; réseau podman `openclaw` créé par `podman-network-openclaw.service` ; snippet Caddy `internal_agent`. Dans `openclaw.nix`, le `let` définit `subnet`, `gateway = "10.89.42.1"`, que la Task 2 réutilise.

- [ ] **Step 1 : vérifier l'état de départ sur srv-1**

```bash
ssh gaugendre@srv-1 'sudo podman network ls; ip -4 route | grep -c 10.89.42 ; sudo ss -ltnp | grep -c 18789'
```
Expected : pas de réseau `openclaw`, `0` route sur `10.89.42`, `0` écoute sur 18789. Sinon, choisir un autre sous-réseau et le reporter partout.

- [ ] **Step 2 : déclarer `agentSubnet`**

Dans `hosts/srv-1/network-vars.nix`, ajouter l'option après `tailscaleIp` :

```nix
    agentSubnet = lib.mkOption {
      type = lib.types.str;
      description = "Podman subnet of the OpenClaw agent. Its identity for the egress rules and for Caddy, which refuses it on `internal` vhosts.";
    };
```
et la valeur dans `config.host.network` :

```nix
    agentSubnet = "10.89.42.0/24";
```

- [ ] **Step 3 : découper le snippet Caddy**

Dans `hosts/srv-1/services/caddy.nix`, remplacer le bloc `(internal) { … }` par :

```nix
      (internal_base) {
        bind ${config.host.network.tailscaleIp}
        @blocked not client_ip private_ranges 2a01:e0a:325:a1c0::/64 fd7a:115c:a1e0::/48 100.0.0.0/8
        respond @blocked "Access denied" 403 {
          close
        }
        tls {
          resolvers 1.1.1.1 1.0.0.1
        }
      }

      # Défaut : l'agent OpenClaw (son sous-réseau est dans private_ranges) est refusé.
      # Un vhost ne lui est ouvert qu'en important internal_agent à la place.
      (internal) {
        import internal_base
        @agent client_ip ${config.host.network.agentSubnet}
        respond @agent "Access denied" 403 {
          close
        }
      }

      (internal_agent) {
        import internal_base
      }
```

- [ ] **Step 4 : ouvrir les quatre vhosts**

Remplacer `import internal` par `import internal_agent` dans exactement ces vhosts :
- `reader.augendre.info` (`miniflux.nix`)
- `wallabag.augendre.info` (`wallabag.nix`)
- `paperless.augendre.info` (`paperless.nix`)
- `jellyfin.srv-1.augendre.info` (`servarr.nix` — **pas** prowlarr, sonarr, radarr, transmission)

```bash
grep -rn "import internal_agent" hosts/srv-1/services/
```
Expected : exactement 4 lignes.

- [ ] **Step 5 : réseau podman et egress**

Créer `hosts/srv-1/services/openclaw.nix` :

```nix
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
```

Ajouter `./openclaw.nix` à la fin de la liste `imports` de `hosts/srv-1/services/default.nix` (avant la ligne commentée `# ./ftp.nix`).

Note : `before = [ "podman-openclaw.service" ]` référence un service qui n'existe qu'à la Task 2 ; systemd l'ignore d'ici là.

- [ ] **Step 6 : documenter dans `CLAUDE.md`**

À la fin de la section « Caddy Internal Access (srv-1) », ajouter :

```markdown
`(internal)` also refuses the OpenClaw agent's podman subnet
(`config.host.network.agentSubnet`), which `private_ranges` would otherwise let
through. A vhost the agent may reach imports `internal_agent` instead — same
`bind` and IP filter, without that refusal. Both build on `(internal_base)`.
The agent's egress (Internet + Caddy:443 only) is in `hosts/srv-1/services/openclaw.nix`.
```

- [ ] **Step 7 : commit, push (go de l'utilisateur), déploiement**

```bash
git add hosts/srv-1/network-vars.nix hosts/srv-1/services/caddy.nix hosts/srv-1/services/miniflux.nix \
  hosts/srv-1/services/wallabag.nix hosts/srv-1/services/paperless.nix hosts/srv-1/services/servarr.nix \
  hosts/srv-1/services/openclaw.nix hosts/srv-1/services/default.nix CLAUDE.md
git commit -m "srv-1: isolate an agent subnet, open four vhosts to it"
# après le go de l'utilisateur :
git push && mise run srv-1
```
Expected : `nixos-rebuild switch` réussit, `caddy`, `firewall` et `podman-network-openclaw` actifs.

- [ ] **Step 8 : tester l'egress et Caddy avec un conteneur jetable**

```bash
ssh gaugendre@srv-1 'bash -s' <<'EOF'
c() { sudo podman run --rm --network openclaw docker.io/curlimages/curl:8.10.1 -sS -m 5 -o /dev/null -w "%{http_code}" "$@" 2>/dev/null; echo " exit=$? $*"; }
echo "--- doivent passer (2xx/3xx)"
c https://example.com
c https://reader.augendre.info/
c https://wallabag.augendre.info/
c https://paperless.augendre.info/
c https://jellyfin.srv-1.augendre.info/
echo "--- 403 attendu"
c https://sonarr.srv-1.augendre.info/
c https://test.augendre.info/
echo "--- timeout attendu (exit=28)"
c http://100.100.100.100/
c http://10.89.42.1:22/
c http://54.36.111.79:8096/
c http://192.168.1.1/
c --resolve reader.augendre.info:8001:100.108.113.85 http://reader.augendre.info:8001/
EOF
```
Expected : exactement le classement annoncé. Un « doit passer » en échec DNS → la règle 53 ne correspond pas à l'aardvark de podman : relever où il écoute (`sudo podman network inspect openclaw`) et corriger.

Puis, depuis le desktop (tailnet), vérifier que rien n'a changé pour l'utilisateur :

```bash
for h in reader.augendre.info sonarr.srv-1.augendre.info paperless.augendre.info; do curl -sS -o /dev/null -w "%{http_code} $h\n" https://$h/; done
```
Expected : 2xx/3xx partout (aucun 403).

- [ ] **Step 9 : survivre aux redémarrages**

```bash
ssh gaugendre@srv-1 'sudo systemctl restart firewall && sudo iptables -t mangle -S PREROUTING | grep openclaw-egress && sudo iptables -t mangle -S openclaw-egress | wc -l'
```
Expected : une ligne `-A PREROUTING -s 10.89.42.0/24 -j openclaw-egress` (une seule : la commande est idempotente) et 12 lignes dans la chaîne (`-N` + 11 règles). Relancer le test du step 8 pour `http://10.89.42.1:22/` : toujours `exit=28`.

---

### Task 2 : le conteneur OpenClaw

**Files:**
- Modify: `hosts/srv-1/age/secrets.nix`
- Modify: `hosts/srv-1/services/openclaw.nix`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: réseau `openclaw`, `subnet`, `gateway` (Task 1).
- Produces: `podman-openclaw.service`, état dans `/var/lib/openclaw` (Task 3 le sauvegarde), secret `openclaw-env`.

- [ ] **Step 1 : règle agenix**

Dans `hosts/srv-1/age/secrets.nix`, ajouter après la dernière règle :

```nix
  "openclaw-env.age".publicKeys = allUsers ++ [ systems.srv-1 ];
```

- [ ] **Step 2 : l'utilisateur crée le secret — STOP**

Demander à l'utilisateur, et attendre qu'il confirme :

```bash
cd hosts/srv-1/age && agenix -e openclaw-env.age
```
contenu, une variable par ligne (format `EnvironmentFile`) :

```
OPENCLAW_GATEWAY_TOKEN=<openssl rand -hex 32>
OVH_AI_ENDPOINTS_API_KEY=<clé d'un projet OVHcloud dédié, quota plafonné>
TELEGRAM_BOT_TOKEN=<BotFather>
TELEGRAM_OWNER_ID=<ID numérique Telegram de l'utilisateur, ex. via @userinfobot>
MINIFLUX_API_KEY=<Miniflux → Paramètres → Clés d'API>
```
Les tokens Paperless (utilisateur `agent`), Jellyfin (non admin) et Wallabag s'ajouteront quand leur usage arrivera. Wallabag n'a pas de token d'API simple (OAuth avec mot de passe) : à rediscuter le moment venu.

- [ ] **Step 3 : relever version, UID et chemin d'état de l'image**

```bash
ssh gaugendre@srv-1 'bash -s' <<'EOF'
sudo podman search --list-tags --limit 500 ghcr.io/openclaw/openclaw | grep -E -- '-browser$' | grep -vE 'beta|latest|main|extended' | sort -V | tail -3
EOF
```
Prendre la plus récente `<version>-browser` stable, puis :

```bash
ssh gaugendre@srv-1 'img=ghcr.io/openclaw/openclaw:<version>-browser; sudo podman pull $img >/dev/null && sudo podman run --rm --entrypoint sh $img -c "id; echo \$HOME; command -v chromium chromium-browser google-chrome 2>/dev/null"'
```
Ajouter `command -v openclaw curl` à la commande `sh -c`.

Expected : `uid=1000(node)`, `HOME=/home/node`, un chemin Chromium, `openclaw` et `curl` présents. Si l'UID ou le chemin diffèrent, les reporter dans `uid` / le montage ci-dessous. Si `openclaw` n'est pas dans le `PATH`, relever la commande de la CLI (`sudo podman inspect --format '{{.Config.Cmd}} {{.Config.Entrypoint}}' <image>`) et l'utiliser partout où ce plan écrit `podman exec openclaw openclaw`. Si `curl` manque, c'est aussi l'outil de l'agent pour les API : le signaler à l'utilisateur avant de continuer.

- [ ] **Step 4 : lire le schéma pour les clés incertaines**

```bash
ssh gaugendre@srv-1 'sudo podman run --rm ghcr.io/openclaw/openclaw:<version>-browser openclaw config schema' > /tmp/openclaw-schema.json
jq '.properties.channels.properties.telegram.properties | {dmPolicy, groupPolicy, allowFrom}' /tmp/openclaw-schema.json
jq '.properties.tools.properties.message' /tmp/openclaw-schema.json
jq '.properties.browser.properties | keys' /tmp/openclaw-schema.json
```
(adapter les chemins jq à la forme réelle du schéma). Confirmer : `dmPolicy` accepte `"allowlist"` ; la valeur de `groupPolicy` qui désactive les groupes (`"disabled"` attendu) ; `tools.message.crossContext.allowAcrossProviders` / `allowWithinProvider`. Corriger la config du step 5 en conséquence — la Gateway refuse de démarrer sur une clé inconnue, donc une erreur se voit au step 7.

- [ ] **Step 5 : conteneur, config, vhost**

Dans `hosts/srv-1/services/openclaw.nix`, compléter le `let` :

```nix
  version = "<version relevée au step 3>";
  stateDir = "/var/lib/openclaw";
  # Utilisateur `node` de l'image (relevé au step 3).
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
  # Les secrets restent des références "${VAR}", résolues par OpenClaw depuis
  # l'environnement du conteneur (environmentFiles) : le store Nix n'en voit aucun.
  settings = {
    gateway = {
      mode = "local";
      port = 18789;
      # "lan" = 0.0.0.0 dans le conteneur ; côté hôte, le port n'est publié que sur 127.0.0.1.
      bind = "lan";
      publicOrigin = origin;
      auth = {
        mode = "token";
        token = "\${OPENCLAW_GATEWAY_TOKEN}";
      };
      # Caddy arrive par le port publié : la Gateway voit la passerelle podman.
      trustedProxies = [ gateway ];
      controlUi.allowedOrigins = [ origin ];
    };
    models = {
      mode = "merge";
      providers.ovhcloud = {
        baseUrl = "https://oai.endpoints.kepler.ai.cloud.ovh.net/v1";
        apiKey = "\${OVH_AI_ENDPOINTS_API_KEY}";
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
      botToken = "\${TELEGRAM_BOT_TOKEN}";
      dmPolicy = "allowlist";
      # L'ID n'est pas un secret mais le repo est public.
      allowFrom = [ "tg:\${TELEGRAM_OWNER_ID}" ];
      groupPolicy = "disabled";
    };
    # L'agent n'écrit que dans la conversation en cours.
    tools.message.crossContext = {
      allowAcrossProviders = false;
      allowWithinProvider = false;
    };
    browser = {
      enabled = true;
      headless = true;
      # Le sandbox de Chromium est une vraie protection contre une page piégée :
      # ne le couper que si le step 9 prouve qu'il ne démarre pas.
      noSandbox = false;
      defaultProfile = "openclaw";
      profiles.openclaw.cdpPort = 18800;
    };
  };
  configFile = pkgs.writeText "openclaw.json" (builtins.toJSON settings);
```

et ajouter dans le corps du module :

```nix
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
```

Si `nixos-rebuild` signale que `networks` n'existe pas dans `oci-containers`, le retirer et ajouter `"--network=openclaw"` à `extraOptions`.

Avant de déployer, vérifier que la plage est libre sur l'hôte :

```bash
ssh gaugendre@srv-1 'getent passwd | awk -F: "\$3>=200000 && \$3<265536" ; grep -E "^[^:]+:2[0-9]{5}:" /etc/subuid'
```
Expected : aucune sortie. Sinon, choisir un autre `uidBase`.

- [ ] **Step 6 : commit, push (go), déploiement**

```bash
git add hosts/srv-1/age/secrets.nix hosts/srv-1/services/openclaw.nix
git commit -m "srv-1: run OpenClaw in a podman container"
# après le go de l'utilisateur :
git push && mise run srv-1
```

- [ ] **Step 7 : la Gateway démarre et la config est valide**

```bash
ssh gaugendre@srv-1 'systemctl is-active podman-openclaw; sudo journalctl -u podman-openclaw -n 50 --no-pager | grep -iE "error|invalid|unknown|warn"; curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18789/healthz'
```
Expected : `active`, aucune erreur de config, aucun avertissement `${…}` non résolu, `200`. Une clé inconnue → corriger d'après le schéma (Task 2 step 4) et redéployer.

Puis le remappage :

```bash
ssh gaugendre@srv-1 'ps -o user:12,uid,cmd -u 201000 | head -3; stat -c "%u %a" /var/lib/openclaw /var/lib/openclaw/openclaw.json'
```
Expected : les processus de la Gateway tournent sous l'UID `201000` (aucun sous `1000`) ; `201000 700` puis `201000 600`.

- [ ] **Step 8 : relever les identifiants de modèles**

```bash
ssh gaugendre@srv-1 'sudo podman exec openclaw sh -c "curl -sS -H \"Authorization: Bearer \$OVH_AI_ENDPOINTS_API_KEY\" https://oai.endpoints.kepler.ai.cloud.ovh.net/v1/models" | jq -r ".data[].id"'
```
Expected : la liste contient `Qwen3.5-397B-A17B` et `gpt-oss-120b` à l'identique. Sinon, corriger `models` dans le `let`, commit, push (go), redéployer.

- [ ] **Step 9 : Telegram, exec et navigateur**

Demander à l'utilisateur d'écrire au bot, successivement :
1. « Bonjour » → réponse.
2. « Exécute `test -n "$MINIFLUX_API_KEY" && echo present` » → `present` (prouve que `exec` hérite des variables du conteneur).
3. « Ouvre https://example.com dans le navigateur et donne-moi le titre » → `Example Domain`.

Si 3 échoue avec une erreur de sandbox Chromium dans `journalctl -u podman-openclaw` : passer `noSandbox = true`, remplacer le commentaire par
`# ponytail: Chromium sans son sandbox (refusé sous podman rootful) ; la frontière est le conteneur seul. Upgrade : profil seccomp dédié, ou la microVM.`, commit, push (go), redéployer, retester.

Si l'utilisateur a un second compte Telegram : un message depuis celui-ci ne reçoit aucune réponse et `sudo journalctl -u podman-openclaw` ne montre aucun traitement. Sinon, le noter comme non testé.

- [ ] **Step 10 : Control UI via Caddy**

L'utilisateur ouvre `https://ai.augendre.info` depuis le tailnet, saisit le token. À la première connexion, « pairing required » :

```bash
ssh gaugendre@srv-1 'sudo podman exec openclaw openclaw devices list'
ssh gaugendre@srv-1 'sudo podman exec openclaw openclaw devices approve <id>'
```
Expected : le Control UI se charge et reste connecté (WebSocket). Si la connexion tombe : vérifier dans les logs l'IP cliente vue par la Gateway et ajuster `trustedProxies`.

- [ ] **Step 11 : l'agent est enfermé, vu de l'intérieur**

```bash
ssh gaugendre@srv-1 'bash -s' <<'EOF'
e() { sudo podman exec openclaw curl -sS -m 5 -o /dev/null -w "%{http_code}" "$@" 2>/dev/null; echo " exit=$? $*"; }
e https://reader.augendre.info/v1/me      # 401 attendu (passe Caddy, pas de token)
e https://ai.augendre.info/                # 403 attendu (son propre Control UI)
e https://sonarr.srv-1.augendre.info/      # 403 attendu
e http://10.89.42.1:22/                    # exit=28
e http://100.100.100.100/                  # exit=28
EOF
```

- [ ] **Step 12 : fallback**

```bash
ssh gaugendre@srv-1 'sudo podman exec openclaw openclaw config set agents.defaults.model.primary ovhcloud/does-not-exist'
```
L'utilisateur écrit au bot « Quel modèle es-tu ? ». Expected : réponse, et `journalctl -u podman-openclaw` montre la bascule vers `gpt-oss-120b`. Puis restaurer :

```bash
ssh gaugendre@srv-1 'sudo systemctl restart podman-openclaw && sudo podman exec openclaw openclaw models'
```
Expected : primaire `ovhcloud/Qwen3.5-397B-A17B` (la recopie du `preStart` a remis la config Nix). Si un modèle inexistant n'enclenche pas la bascule (erreur de config plutôt que d'appel), le noter dans le compte rendu : le fallback reste à prouver sur une vraie panne.

- [ ] **Step 13 : audit**

```bash
ssh gaugendre@srv-1 'sudo podman exec openclaw openclaw security audit'
```
Puis plugins et skills (la doc ne donne pas d'interrupteur global pour ClawHub) :

```bash
ssh gaugendre@srv-1 'sudo podman exec openclaw openclaw plugins list; sudo podman exec openclaw openclaw skills list'
```
Expected : seulement ce qui est livré avec l'image, rien d'installé depuis ClawHub. Si `openclaw config schema` révèle une clé pour interdire les installations, l'ajouter à `settings`.

Expected pour l'audit : aucun finding critique. Chaque finding restant est rapporté à l'utilisateur avec sa décision (corrigé dans la config Nix, ou accepté et pourquoi). À noter dans le compte rendu : avec `exec`, l'agent peut techniquement installer un skill lui-même ; c'est la limite acceptée de l'option A.

- [ ] **Step 14 : documenter dans `CLAUDE.md`**

Dans « Key Patterns », ajouter :

```markdown
- OpenClaw (`hosts/srv-1/services/openclaw.nix`): `openclaw.json` is generated by Nix and **copied** into `/var/lib/openclaw` at every start (the Gateway rewrites its file and rejects symlinks), so a change made from the Control UI or `openclaw config set` is lost at restart — make it in Nix. Secrets stay `${VAR}` references, resolved from `openclaw-env.age`. Agent egress is limited to Internet + Caddy:443 by the `openclaw-egress` chain (table `mangle`, so netavark's own rules cannot jump ahead of it).
```

```bash
git add CLAUDE.md hosts/srv-1/services/openclaw.nix
git commit -m "Document the OpenClaw setup on srv-1"
```

---

### Task 3 : sauvegarde

**Files:**
- Modify: `hosts/srv-1/services/restic.nix`

- [ ] **Step 1 : relever les caches Chromium**

```bash
ssh gaugendre@srv-1 'sudo find /var/lib/openclaw -type d \( -name Cache -o -name "Code Cache" -o -name GPUCache -o -name ShaderCache -o -name GrShaderCache \) -prune | sed "s|/var/lib/openclaw/||"'
```
Expected : des chemins sous le profil Chromium. S'il y en a d'autres gros et jetables, `sudo du -sh /var/lib/openclaw/*` aide à les repérer.

- [ ] **Step 2 : ajouter path, exclusions, arrêt**

Dans `restic.nix`, ajouter à `servicesToStop` :

```nix
    # OpenClaw
    "podman-openclaw.service"
```
à `paths` :

```nix
        # Mémoire, sessions, appairage, crons et profil Chromium (cookies des sites connectés).
        "/var/lib/openclaw"
```
à `exclude` :

```nix
        # Caches Chromium de l'agent : jetables.
        "/var/lib/openclaw/**/Cache"
        "/var/lib/openclaw/**/Code Cache"
        "/var/lib/openclaw/**/GPUCache"
        "/var/lib/openclaw/**/ShaderCache"
        "/var/lib/openclaw/**/GrShaderCache"
```

- [ ] **Step 3 : commit, push (go), déploiement, sauvegarde manuelle**

```bash
git add hosts/srv-1/services/restic.nix
git commit -m "srv-1: back up OpenClaw state"
# après le go :
git push && mise run srv-1
ssh gaugendre@srv-1 'sudo systemctl start restic-backups-local && systemctl is-active podman-openclaw && sudo restic-local ls latest /var/lib/openclaw | head -20 && sudo restic-local ls latest /var/lib/openclaw | grep -c "/Cache/"'
```
Expected : la sauvegarde se termine, `podman-openclaw` est de nouveau `active`, des fichiers d'OpenClaw sont listés, et `0` entrée sous un `/Cache/`.

---

### Task 4 : récap du matin (test de bout en bout)

Pas de code : l'agent se configure par conversation. Ce qui est vérifié, c'est que l'ensemble tient.

- [ ] **Step 1 : créer le cron par Telegram**

L'utilisateur écrit au bot :

> Crée une tâche planifiée tous les jours à 7h30 (Europe/Paris) : récupère mes articles non lus Miniflux avec `curl -sS -H "X-Auth-Token: $MINIFLUX_API_KEY" "https://reader.augendre.info/v1/entries?status=unread&limit=100&order=published_at&direction=desc"`, puis envoie-moi ici un récap groupé par thème, avec un lien par article. Ne marque rien comme lu.

- [ ] **Step 2 : déclencher une fois**

```bash
ssh gaugendre@srv-1 'sudo podman exec openclaw openclaw cron list'
ssh gaugendre@srv-1 'sudo podman exec openclaw openclaw cron run <id>'
```
Expected : le récap arrive sur Telegram, avec des liens `reader.augendre.info` ou d'origine. 7h30 est après la sauvegarde de 02:00.

- [ ] **Step 3 : le cron survit au redémarrage**

```bash
ssh gaugendre@srv-1 'sudo systemctl restart podman-openclaw && sleep 15 && sudo podman exec openclaw openclaw cron list'
```
Expected : la tâche est toujours là (les crons vivent dans l'état, pas dans `openclaw.json` que le `preStart` écrase). Si elle a disparu : les crons sont dans la config → les déclarer dans `settings` côté Nix, et le noter dans `CLAUDE.md`.

- [ ] **Step 4 : clore la spec**

Dans `docs/superpowers/specs/2026-10-10-openclaw-srv-1-design.md`, remplacer la ligne de statut par :

```markdown
Statut : déployé (image `<version>-browser`). Écarts à l'implémentation : <liste, ou « aucun »>.
```
et ajuster les sections « À vérifier à l'implémentation » en constats. Commit `Mark the OpenClaw spec as deployed`, push après le go.
