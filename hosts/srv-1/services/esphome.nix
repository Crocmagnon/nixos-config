# Serveur de compilation distant pour l'add-on ESPHome Device Builder de HA.
#
# Répartition des rôles : l'add-on reste le "sender" — il garde les YAML et
# fait lui-même l'OTA (et le flash USB) sur le LAN. srv-1 ne fait que compiler,
# ce qui sort du Home Assistant Green les ~5,7 Go de cache PlatformIO.
# Aucune route Tailscale à approuver : srv-1 n'a jamais besoin de joindre les
# ESP, c'est HA qui flashe. Il faut en revanche une grant Tailscale de chaque
# HA vers tag:nix, sur le port de son builder, pour que le peer-link passe.
#
# Deux builders, un par HA : en --remote-build-only, le device-builder
# n'accepte qu'UN appairage, par conception ("exactly one pairing is
# allowed"). Le HA de la maison (tag:home) compile sur le port 6055, celui des
# parents (tag:parents) sur le 6056. Chacun a son état, donc son identité et
# ses builds : le HA des parents ne voit rien de ceux de la maison.
#
# Pourquoi un conteneur et pas services.esphome / le paquet nixpkgs :
# à chaque build, ESPHome installe le framework ESP-IDF en téléchargeant des
# binaires précompilés (cmake, ninja, xtensa-esp-elf) liés dynamiquement à une
# glibc générique. NixOS ne peut pas les exécuter :
#   "Could not start dynamically linked executable: .../bin/cmake"
#   https://nix.dev/permalink/stub-ld
# Testé, c'est sans issue : le paquet nixpkgs installe correctement, puis meurt
# à la première toolchain téléchargée. Un buildFHSEnv serait à deviner et à
# maintenir ; l'image officielle est du Debian où ces binaires tournent, et
# c'est le chemin supporté en amont.
#
# La version de l'image n'a presque pas d'importance : le device-builder
# provisionne un venv avec la version exacte d'ESPHome demandée par le sender
# ("Provisioning esphome 2026.8.0 into an isolated environment"). L'image ne
# fournit que l'environnement FHS et le device-builder lui-même (>= 2026.6.0).
#
# Appairage (une fois) :
#   1. journalctl -u podman-esphome -f (ou podman-esphome-parents)
#      → relever l'empreinte et la clé
#   2. dans l'add-on : Paramètres → Envoyer les compilations → "Pair with a
#      build server", saisir <ip-tailscale-srv-1> et le port du builder
#      (mDNS ne traverse pas Tailscale, la découverte automatique ne verra rien)
# La fenêtre dure 15 min ; passé ce délai le process sort et le conteneur
# redémarre, ce qui régénère une NOUVELLE clé.
{ config, lib, ... }:
let
  # Les HA se sont appairés en IPv4 : seul le port v4 est publié.
  tailscaleIp4 = builtins.head (lib.splitString " " config.host.network.tailscaleIp);
  # stateDir contient l'identité peer-link et l'état de build : il doit rester
  # persistant, sinon l'appairage est à refaire. Monté au même chemin dans le
  # conteneur pour que les chemins de cache restent lisibles entre l'hôte et
  # le log.
  builder = stateDir: port: {
    image = "ghcr.io/esphome/esphome:2026.11.0@sha256:6351ae811202064bb3eb49dde982609b47acd523103a66d7b9c5c1431beea055";
    volumes = [ "${stateDir}:${stateDir}" ];

    # HOME explicite : sinon le cache ESP-IDF atterrit dans /root du conteneur
    # et se perd à chaque recréation, forçant un re-téléchargement complet.
    environment.HOME = stateDir;

    cmd = [
      "--remote-build-only"
      # Dans le conteneur ; c'est la publication du port (ci-dessous) qui le
      # limite à l'IP Tailscale de srv-1.
      "--remote-build-host"
      "0.0.0.0"
      # Explicite : si le port est pris, le builder en choisit un autre
      # silencieusement, et l'appairage viserait le mauvais.
      "--remote-build-port"
      (toString port)
      stateDir
    ];

    # Réseau bridge, pas host : le builder exécute du code venu des HA (scripts
    # PlatformIO, external_components). En réseau host, il atteindrait le
    # localhost de srv-1, où les *arr, Calibre-web et l'admin API de Caddy ne
    # demandent rien. Publié sur l'IP Tailscale seulement (le bind avant que
    # tailscale0 ait son IP passe grâce à net.ipv4.ip_nonlocal_bind, cf. caddy.nix).
    ports = [ "${tailscaleIp4}:${toString port}:${toString port}" ];

    extraOptions = [
      # L'entrypoint de l'image est `esphome` (le CLI) : sans override, cmd est
      # interprété comme une sous-commande esphome et le conteneur meurt sur
      # "invalid choice". Le device-builder a son propre binaire.
      "--entrypoint=esphome-device-builder"
    ];
  };
in
{
  # TODO(26.11): Podman 6 drops BoltDB and iptables; upstream advises `nixos-rebuild boot` and a
  # reboot to finish the migration. auto-upgrade boots first, but only reboots on a kernel/initrd
  # change: if that release doesn't bring one, reboot by hand. The builders use the bridge network
  # with a published port: after the migration, check both HA still reach them (peer-link on
  # 6055/6056) and a build still downloads its toolchain (DNS and outbound NAT).
  virtualisation.oci-containers.containers = {
    esphome = builder "/var/lib/esphome" 6055;
    esphome-parents = builder "/var/lib/esphome-parents" 6056;
  };

  # Podman refuse de monter un dossier hôte absent.
  systemd.tmpfiles.rules = [ "d /var/lib/esphome-parents 0700 root root -" ];
}
