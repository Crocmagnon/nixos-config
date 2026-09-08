# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Rebuild and switch (uses nh, auto-detects hostname)
nh os switch .

# Rebuild without switching (dry run)
nixos-rebuild dry-build --flake .#<hostname>

# Check flake validity
nix flake check

# Update flake inputs
nix flake update

# Update a single input
nix flake update <input-name>
```

## Secrets Management

Secrets are managed with agenix. Two independent secret stores:

```bash
# srv-1 (system-level, decrypted at boot with the host SSH key)
cd hosts/srv-1/secrets
nix run github:ryantm/agenix -- -e <secret-name>.age

# desktops (home-manager module, decrypted in the user session ->
# $XDG_RUNTIME_DIR/agenix/). Desktops have no SSH host key, and ~/.ssh/id_ed25519
# has a passphrase age cannot get from kwallet, so the systemd service decrypts
# with a dedicated passphrase-less age key: ~/.config/agenix/identity.txt
# (created by hand with `age-keygen`, never committed -- back it up).
# The SSH key stays a recipient so `-e`/`-r` work with the default identity.
# After changing recipients: `nix run github:ryantm/agenix -- -r`
cd modules/home/gaugendre/desktop/secrets
nix run github:ryantm/agenix -- -e <secret-name>.age
```

`secrets/fonts/` is a third rules file (same recipients, imported from the parent
one) holding the licensed OTFs: binary, so they're encrypted with `age -r` by hand
rather than `agenix -e`. A rotation means `agenix -r` in **both** directories.

## Architecture

This is a NixOS flake configuration for three machines:
- **framework-gab**: Framework laptop (AMD AI 300 series)
- **desktop-gab**: Desktop workstation (Gigabyte B650)
- **srv-1**: Server (uses disko for disk management, agenix for secrets)

### Module Hierarchy

**System-level** (`modules/nixos/`):
- `common/` → Base config for **all** machines (nix settings, fish, basic packages, home-manager setup)
  - `default.nix` → Entry point, imports `save-disk.nix`, `home-manager.nix`, `users.nix`
  - `users.nix` → Common user definition (gaugendre + root), SSH keys, passwordless sudo
  - `home-manager.nix` → Base HM config for gaugendre + root
- `desktop/` → Config for **desktop machines only** (desktop-specific features, does NOT import common)
  - `default.nix` → Entry point, imports locale, fonts, audio, iphone, boot, docker, plasma, desktop HM, users, vpn, uv-python, nrfconnect, flatpak. Also holds the desktop packages (Kate, FreeCAD, etc.), Firefox, Steam, KDE Connect
  - `users.nix` → Desktop-specific user groups (`networkmanager`, `dialout`)
  - `home-manager.nix` → Desktop-only HM additions (imports `modules/home/gaugendre/desktop/`)
  - `plasma.nix`, `audio.nix`, `boot.nix`, `locale.nix`, `fonts.nix`, `docker.nix`, `iphone.nix`, `vpn.nix`, `uv-python.nix`, `nrfconnect.nix`, `rotatrix.nix`, `virt.nix`, `flatpak.nix`

**Home-manager** (`modules/home/`):
- `gaugendre/home.nix` → Base user config for all machines (imports `shared/`, `git.nix`)
- `gaugendre/desktop/` → Desktop-only HM modules (krunner-autostart, konsole, kwallet-ssh, email, zed, vscode, plasma, rust, go, lua, devenv, ai-agents)
- `gaugendre/desktop/ai-agents.nix` → Claude Code config (gaugendre only — not shared with root)
- `shared/` → Reusable modules for **all** users (fish, bat, eza, starship, helix, fresh) — imported by both gaugendre and root
- `root/home.nix` → Root user HM config

**Shared helpers** (`lib/`):
- `identity.nix` → Single source of truth for `fullName` / `email`. Imported via `let identity = import .../lib/identity.nix` in git, email account, Caddy ACME, etc.

**Host-specific** (`hosts/<hostname>/`):
- `configuration.nix` → Entry point, imports hardware + `modules/nixos/common` + `modules/nixos/desktop` (desktops) or `modules/nixos/common` only (servers)
- `srv-1/network-vars.nix` → Declares `host.network.{ipv6,ipv6gw,interface,tailscaleIp}` options (typed, via `lib.mkOption`). Consumed by `network.nix` and Caddy vhosts as `config.host.network.*`.
- `srv-1/services/default.nix` → Aggregates all service imports for srv-1. `configuration.nix` just imports `./services`.

### Key Patterns

- Desktops import both `modules/nixos/common` and `modules/nixos/desktop`. Servers import `modules/nixos/common` only.
- Home-manager is configured via `modules/nixos/common/home-manager.nix` with `useGlobalPkgs = true`
- Desktop HM additions are in `modules/nixos/desktop/home-manager.nix`
- Catppuccin theming is enabled on desktops (`catppuccin.enable = true`). srv-1 does **not** load `catppuccin.nixosModules.catppuccin` at the NixOS level (only the home-manager module via gaugendre).
- `overlays/unstable-packages.nix` replaces a fixed list of packages (btop, uv, claude-code, gopls, koreader…) by their nixpkgs-unstable version, under their usual `pkgs.<package>` name. To get another one from unstable, add it to that list.
- `nh os switch .` is the preferred rebuild command (wraps nixos-rebuild with niceties)
- Proprietary AppImages (`rotatrix.nix`) are packaged with a fixed-output `runCommand` that curls the vendor URL + `appimageTools.wrapType2`. The binary and the license-gated download key are never committed (public repo); the key sits in `/etc/rotatrix-key` and reaches the builder through `nix.settings.extra-sandbox-paths` — see "Proprietary AppImages" in `README.md`. `wrapType2` only symlinks the binary, so the `.desktop` and icons must be installed by hand via `extraInstallCommands` (pull them out with `appimageTools.extract`).
- udev: `services.udev.extraRules` lands in `/etc/udev/rules.d/99-local.rules`, which runs **after** systemd's `73-seat-late.rules`, so a `TAG+="uaccess"` there is silently ignored. Use `GROUP`/`MODE` (`rotatrix.nix`), or ship a rules file numbered below 70 via `services.udev.packages` (`nrfconnect.nix`). The `plugdev` group does not exist on NixOS.
- Autostart of a **graphical** app: install its `.desktop` into `$out/etc/xdg/autostart` (`/etc/xdg/autostart` is in `environment.pathsToLink`, so it lands in `/run/current-system/sw/etc/xdg/autostart`), not a `systemd.user.services` unit on `graphical-session.target` — that unit starts before Plasma has published `DISPLAY`/`WAYLAND_DISPLAY` into the user systemd manager, which breaks anything touching X (cost us a `pynput` `ImportError` in `rotatrix.nix`). A systemd user unit is still right for a display-less daemon (`modules/home/gaugendre/desktop/krunner-autostart.nix`).
- `flake.nix` uses a local `mkHost` helper to factor common modules (`home-manager`, `unstable-packages` overlay). Hosts only declare their `extraModules` (and `extraOverlays` for srv-1).

### Caddy Internal Access (srv-1)

To restrict a Caddy virtualHost to internal/Tailscale access, `import internal` in the virtualHost's `extraConfig` is sufficient. The `(internal)` snippet (defined in `hosts/srv-1/services/caddy.nix`) handles both:

1. `bind ${config.host.network.tailscaleIp}` — listen only on the Tailscale interface
2. IP-based access control via `client_ip` matcher (private ranges + Tailscale CGNAT)

Both are required: without `bind`, Caddy still listens on all interfaces even though the IP filter would reject external requests. Both live in the snippet so a vhost cannot import only one half.
