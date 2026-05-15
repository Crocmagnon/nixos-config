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

Secrets are managed with agenix (srv-1 only):
```bash
cd hosts/srv-1/secrets
nix run github:ryantm/agenix -- -e <secret-name>.age
```

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
  - `default.nix` → Entry point, imports locale, fonts, audio, boot, docker, plasma, users, vpn, uv-python, desktop HM
  - `users.nix` → Desktop-specific user packages (Kate, PrusaSlicer, JetBrains, etc.), Firefox, Steam, KDE Connect
  - `home-manager.nix` → Desktop-only HM additions (konsole, email, zed, vscode, krunner)
  - `plasma.nix`, `audio.nix`, `boot.nix`, `locale.nix`, `fonts.nix`, `docker.nix`, `iphone.nix`, `vpn.nix`, `uv-python.nix`, `virt.nix`

**Home-manager** (`modules/home/`):
- `gaugendre/home.nix` → Base user config for all machines (imports `shared/` + git)
- `gaugendre/desktop/` → Desktop-only HM modules (konsole, email, zed, vscode, krunner)
- `shared/` → Reusable modules across all machines (fish, helix, starship, eza, ai-agents)
- `root/home.nix` → Root user HM config

**Host-specific** (`hosts/<hostname>/`):
- `configuration.nix` → Entry point, imports hardware + `modules/nixos/common` + `modules/nixos/desktop` (desktops) or `modules/nixos/common` only (servers)

### Key Patterns

- Desktops import both `modules/nixos/common` and `modules/nixos/desktop`. Servers import `modules/nixos/common` only.
- Home-manager is configured via `modules/nixos/common/home-manager.nix` with `useGlobalPkgs = true`
- Desktop HM additions are in `modules/nixos/desktop/home-manager.nix`
- Catppuccin theming is enabled globally (`catppuccin.enable = true`)
- Unstable packages available via overlay as `pkgs.unstable.<package>`
- `nh os switch .` is the preferred rebuild command (wraps nixos-rebuild with niceties)

### Caddy Internal Access (srv-1)

To restrict a Caddy virtualHost to internal/Tailscale access, `import internal` in the virtualHost's `extraConfig` is sufficient. The `(internal)` snippet (defined in `hosts/srv-1/services/caddy.nix`) handles both:

1. `bind ${config.host.network.tailscaleIp}` — listen only on the Tailscale interface
2. IP-based access control via `client_ip` matcher (private ranges + Tailscale CGNAT)

Both are required: without `bind`, Caddy still listens on all interfaces even though the IP filter would reject external requests. Both live in the snippet so a vhost cannot import only one half.
