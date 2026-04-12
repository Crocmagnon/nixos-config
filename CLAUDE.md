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
- `common.nix` → Base config for all machines (imports home-manager setup)
- `common-desktop.nix` → Desktop machines (imports common + locale, fonts, audio, boot)

**Home-manager** (`home/`):
- `home/gaugendre/home.nix` → Main user config (imports `home/shared/`)
- `home/shared/` → Reusable modules across all machines

**Host-specific** (`hosts/<hostname>/`):
- `configuration.nix` → Entry point, imports hardware + relevant modules
- `home/default.nix` → Host-specific home-manager additions

### Key Patterns

- Home-manager is configured via `modules/nixos/home-manager.nix` with `useGlobalPkgs = true`
- Catppuccin theming is enabled globally (`catppuccin.enable = true`)
- Unstable packages available via overlay as `pkgs.unstable.<package>`
- `nh os switch .` is the preferred rebuild command (wraps nixos-rebuild with niceties)

### Caddy Internal Access (srv-1)

To restrict a Caddy virtualHost to internal/Tailscale access, **both** of these are required:

1. `import internal` in the virtualHost's `extraConfig` (IP-based access control)
2. `bind ${tailscaleIp}` in the virtualHost's `extraConfig` (listen only on Tailscale interface)

The module must also accept `tailscaleIp` as a function argument. Without `bind`, Caddy still listens on all interfaces even though `import internal` rejects external requests.
