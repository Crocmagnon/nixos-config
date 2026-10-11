# OpenClaw sur srv-1

Date : 2026-10-10
Statut : déployé le 2026-10-11 (image `2026.9.9-browser`). Écarts à l'implémentation :
`order respond first` dans Caddy, remappage des UID, `plugins.allow`, fallback privé
d'outils web, skill semée dans le workspace — détaillés dans « Constats ».

## Problème

Un assistant personnel du genre OpenClaw, joignable par Telegram, qui :

- converse, cherche sur le web, résume, rappelle (usage A) ;
- agit sur des API choisies : Miniflux, Wallabag, Jellyfin, Paperless (usage B) —
  premier cas visé : un récap du matin des flux RSS ;
- pilote un navigateur sur des sites tiers : récap et modification des recettes
  Recettes & Cabas, téléchargement d'un PDF vers Paperless.

Pas de développement, pas d'action sur les machines. Un seul utilisateur.

La contrainte qui dimensionne tout : l'agent lit des pages web arbitraires, donc de
l'injection de prompt, tout en tenant des tokens et des sessions connectées. Le design
borne ce qu'une page piégée peut atteindre ; il ne prétend pas l'empêcher d'agir dans
ce périmètre.

## Décisions

| Sujet | Choix | Écarté, et pourquoi |
|---|---|---|
| Logiciel | OpenClaw, image officielle `ghcr.io/openclaw/openclaw:<tag>-browser` | NanoClaw (un conteneur par conversation → socket podman), Hermes (pas de gain net) |
| Isolation | conteneur podman (`oci-containers`), comme wallabag/esphome | microVM : frontière noyau, mais un input et une VM de plus. Reste la sortie de secours, même config |
| Modèle | AI Endpoints OVHcloud seul : `Qwen3.5-397B-A17B` primaire, `gpt-oss-120b` en fallback | Claude : abonnement d'entreprise, binaire `claude` + OAuth dans le conteneur, politique Anthropic mouvante |
| Canal | Telegram (bot, long polling) | Signal (numéro dédié + `signal-cli`), Matrix (un service de plus) |
| Interface web | `ai.augendre.info`, Caddy `bind` IP Tailscale | Tailscale Serve |
| Outils | `exec` autorisé **dans** le conteneur, tokens à portée minimale | MCP par service (du code par idée), approbation de chaque commande (bloque les crons) |

Telegram : les bots n'ont pas de chats secrets, Telegram voit les échanges. L'agent
envoie des liens (Paperless…), pas de documents sensibles.

Choix des modèles (catalogue `catalog.endpoints.ai.ovh.net/rest/v1/models_v2`, filtre
`function_calling`) : Qwen3.5-397B-A17B est le plus gros, raisonne, 262k de contexte et
**voit les images** (captures d'écran du navigateur) — 0,60 / 3,60 par M tokens.
gpt-oss-120b est d'une autre famille, donc tombe en panne indépendamment, et coûte
0,08 / 0,40. Une panne de toute la plateforme AI Endpoints n'est pas couverte.
`Qwen3.8-27B` est le plan B si le 397B est trop lent.

## Architecture

```
téléphone ── Telegram ◄──── long polling sortant ────┐
navigateur (tailnet) ─► Caddy ai.augendre.info        │
                        (internal) ─► 127.0.0.1:18789 ─► conteneur openclaw
                                                       │  réseau podman 10.89.42.0/24
                                                       │  /var/lib/openclaw (seul montage)
                                                       ├─► Internet : AI Endpoints, Telegram, sites
                                                       ├─► Caddy 443 (IP Tailscale), vhosts `internal_agent` seulement
                                                       └─✕ tailnet, plages privées, autres ports de srv-1
```

### Conteneur

`hosts/srv-1/services/openclaw.nix` :

- image `-browser` (Chromium dans le Gateway) pinnée sur un tag, jamais `latest` ;
- un seul montage hôte : `/var/lib/openclaw` (état, workspace, profil Chromium) ; pas de
  socket podman, aucun dossier de srv-1 ;
- réseau podman dédié à sous-réseau fixe (`10.89.42.0/24`) : c'est l'identité de
  l'agent pour le firewall et pour Caddy. `oci-containers` ne gère pas les réseaux, il
  faut le créer (oneshot `podman network create`) ;
- Control UI publié sur `127.0.0.1:18789` ;
- `openclaw.json` généré par Nix, monté en lecture seule ; secrets par variables
  d'environnement depuis `environmentFiles`.

### Entrée

Vhost `ai.augendre.info` (DNS : `terraform-ovh`, commit `1970b58`) :
`import common_headers`, `import internal`, `reverse_proxy localhost:18789`. Le token du
Gateway s'ajoute par-dessus. Telegram n'expose rien : long polling sortant.

### Sortie

Depuis `10.89.42.0/24` :

- autorisé : Internet ;
- autorisé : `tcp/443` sur l'IP Tailscale de srv-1 (Caddy), et le DNS de podman si le
  conteneur en dépend ;
- rejeté : `100.64.0.0/10`, `fd7a:115c:a1e0::/48`, `10.0.0.0/8`, `172.16.0.0/12`,
  `192.168.0.0/16`, `169.254.0.0/16`, et tout autre port de srv-1.

Le firewall de srv-1 est celui de NixOS (iptables) et netavark insère ses propres
règles : l'ordre est à établir à l'implémentation, et les tests ci-dessous en sont la
preuve, pas la lecture des règles.

### Services de srv-1 : liste fermée, dans Caddy

L'agent passe par les mêmes URL que l'utilisateur. Or `(internal)` accepte
`private_ranges`, donc le sous-réseau de l'agent : sans changement, il atteindrait
tous les vhosts internes, Sonarr, Transmission et son propre Control UI compris.

`caddy.nix` découpe le snippet :

- `(internal_base)` : le contenu actuel (`bind`, filtre IP, `tls`) ;
- `(internal)` : `import internal_base` + refus de `10.89.42.0/24`. Défaut, aucun vhost
  existant ne change ;
- `(internal_agent)` : `import internal_base` seul.

Passent à `internal_agent` : `reader` (Miniflux), `wallabag`, `jellyfin.srv-1`,
`paperless`. Ouvrir un service à l'agent = une ligne dans son module.

## Configuration OpenClaw

- fournisseur `ovhcloud` : `baseUrl https://oai.endpoints.kepler.ai.cloud.ovh.net/v1`,
  `api: openai-completions`, `compat.supportsStore = false` ;
- `agents.defaults.model.primary` = Qwen3.5-397B-A17B,
  `agents.defaults.model.fallbacks` = [gpt-oss-120b] — identifiants exacts relevés sur
  `/v1/models` ;
- Telegram : `dmPolicy` en `allowlist`, l'ID Telegram de l'utilisateur seul ;
- envoi de messages restreint à la conversation courante (pas de cross-provider) ;
- plugins tiers et ClawHub désactivés ;
- `exec` autorisé, sans sandbox imbriquée (le conteneur est la sandbox) ;
- navigateur headless de l'image.

## Secrets

Un secret agenix `openclaw-env.age` (règle dans `hosts/srv-1/age/secrets.nix`, rien
d'autre à toucher : `default.nix` dérive `age.secrets`). L'utilisateur fait lui-même
l'`agenix -e`. Contenu :

| Variable | Portée |
|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | généré pour l'occasion |
| clé AI Endpoints | projet OVHcloud dédié, quota plafonné |
| token du bot Telegram | BotFather |
| token Paperless | utilisateur `agent` : ajouter des documents, lire les siens |
| token Jellyfin | utilisateur non admin |
| clés Miniflux, Wallabag | compte de l'utilisateur (pas de clé lecture seule) — risque accepté |

Avec `exec`, une page piégée peut lire ces variables et les exfiltrer : c'est le coût
accepté de l'option A, d'où des portées minimales et un quota plafonné.

## Sauvegarde

`/var/lib/openclaw` va dans les `paths` de restic (`restic.nix`) : mémoire, sessions,
config d'appairage, workspace, crons, et le profil Chromium — dont les cookies des sites
connectés, ce qui évite de se reconnecter partout après une restauration. Le dépôt
restic est chiffré.

- `exclude` : les caches de Chromium (`Cache`, `Code Cache`, `GPUCache`…), jetables ;
  chemins exacts relevés une fois le profil créé ;
- `podman-openclaw.service` rejoint `servicesToStop`, comme les autres services à état :
  la sauvegarde à 02:00 l'arrête, le récap du matin est donc à planifier après.

## Mises à jour

Tag d'image pinné, montée manuelle. Le rythme des CVE OpenClaw est élevé (RCE
CVE-2026-25253, ClawJacked) : surveiller les releases. Après chaque montée :
`openclaw security audit`.

## Tests de mise en service

1. Depuis le conteneur (`podman exec openclaw curl …`) :
   - passent : un site public, `reader`, `wallabag`, `jellyfin.srv-1`, `paperless` ;
   - échouent : un vhost `internal` (Sonarr, `ai.augendre.info` lui-même), une IP du
     tailnet, `srv-1:8001` en direct, une IP privée.
2. Un message Telegram depuis un autre compte est ignoré.
3. Primaire volontairement faux → `gpt-oss-120b` répond ; puis primaire rétabli.
4. `openclaw security audit` sans finding critique.
5. Le récap du matin des flux Miniflux, en cron OpenClaw, fait le test de bout en bout.

## Constats

- **Config.** La Gateway réécrit son fichier et refuse un symlink : Nix le recopie à
  chaque démarrage. Elle compare aussi le fichier à ses sauvegardes `.bak` et restaure
  celle-ci si le fichier rétrécit de plus de moitié ou perd `meta` : le `preStart`
  supprime d'abord ces sauvegardes. Les tokens sont des SecretRef (le doctor tient une
  chaîne `${VAR}` pour un secret en clair) ; la clé OVHcloud finit malgré tout dans
  `state/openclaw.sqlite`.
- **État et UID.** `/home/node/.openclaw`, utilisateur `node` (1000). Sans remappage,
  c'est l'UID 1000 de l'hôte, qui a sudo : `--uidmap=0:200000:65536`.
- **Firewall.** La chaîne `openclaw-egress` en table `mangle` passe avant netavark ;
  elle survit au restart et au reload du firewall.
- **Caddy.** `redir`, `handle` et `route` passent avant `respond` : le refus des
  snippets `internal` ne s'appliquait pas à odoo ni à test. Corrigé par
  `order respond first`, ce qui bouche aussi le même trou pour `@blocked`.
- **Plugins.** Le navigateur et Telegram sont des plugins livrés : `plugins.allow` en
  liste fermée plutôt que `plugins.enabled = false`.
- **Audit.** `gpt-oss-120b` est jugé trop petit pour du web non fiable : en secours,
  plus de navigateur ni de web (`tools.byProvider`). Limite d'essais sur l'auth,
  `tools.elevated` coupé.
- **Bail d'état.** Tuée après 10 s, la Gateway gardait un bail de 5 min que le conteneur
  suivant, sous un autre nom d'hôte, ne pouvait reprendre : `--hostname=openclaw`,
  `--stop-timeout=60`.
- **Skills.** Une skill montée depuis le store est refusée (fichier en lien physique).
  La skill `srv-1-services` est semée une fois dans le workspace et appartient ensuite
  à l'agent, qui y note ses recettes.
- **Sauvegarde.** Le post-stop de restic s'interbloquait chaque nuit avec `conflicts`
  (préexistant) : `systemctl start --no-block`.

## Hors périmètre

Recettes & Cabas (identifiants ajoutés à `openclaw-env.age`), téléchargements de PDF et autres usages : de la configuration
d'agent, pas de l'infrastructure. Ils viennent une fois l'agent en place, avec au
besoin une connexion manuelle au site dans le navigateur de l'agent.
