# Serveur de compilation distant pour l'add-on ESPHome Device Builder de HA.
#
# Répartition des rôles : l'add-on reste le "sender" — il garde les YAML et
# fait lui-même l'OTA (et le flash USB) sur le LAN. srv-1 ne fait que compiler,
# ce qui sort du Home Assistant Green les ~5,7 Go de cache PlatformIO.
# Aucune route Tailscale à approuver : srv-1 n'a jamais besoin de joindre les
# ESP, c'est HA qui flashe. Il faut en revanche une grant tag:home -> tag:nix
# sur le port 6055 pour que le peer-link passe.
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
#   1. journalctl -u podman-esphome -f  → relever l'empreinte et la clé
#   2. dans l'add-on : Paramètres → Envoyer les compilations → "Pair with a
#      build server", saisir <ip-tailscale-srv-1>:6055 (mDNS ne traverse pas
#      Tailscale, la découverte automatique ne verra rien)
# La fenêtre dure 15 min ; passé ce délai le process sort et le conteneur
# redémarre, ce qui régénère une NOUVELLE clé.
{ ... }:
let
  # Contient l'identité peer-link et l'état de build : doit rester persistant,
  # sinon l'appairage est à refaire. Monté au même chemin dans le conteneur
  # pour que les chemins de cache restent lisibles entre l'hôte et le log.
  stateDir = "/var/lib/esphome";
in
{
  virtualisation.oci-containers.containers.esphome = {
    image = "ghcr.io/esphome/esphome:2026.10.1@sha256:eab8cd6b4f51077c3883af4cedc058280ddc34a94f3b2ffee23e9d2cd5f1db64";
    volumes = [ "${stateDir}:${stateDir}" ];

    # HOME explicite : sinon le cache ESP-IDF atterrit dans /root du conteneur
    # et se perd à chaque recréation, forçant un re-téléchargement complet.
    environment.HOME = stateDir;

    cmd = [
      "--remote-build-only"
      # Accepte un nom d'interface : le peer-link n'écoute que sur le tailnet.
      # En réseau host, le firewall NixOS s'applique normalement — un port
      # publié par Docker, lui, contournerait allowedTCPPorts.
      "--remote-build-host"
      "tailscale0"
      stateDir
    ];

    extraOptions = [
      # Réseau host : le conteneur voit tailscale0 directement, donc pas de
      # mapping de ports à publier et pas de contournement du firewall.
      "--network=host"
      # L'entrypoint de l'image est `esphome` (le CLI) : sans override, cmd est
      # interprété comme une sous-commande esphome et le conteneur meurt sur
      # "invalid choice". Le device-builder a son propre binaire.
      "--entrypoint=esphome-device-builder"
    ];
  };
}
