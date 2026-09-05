---
description: Add a new NixOS machine (desktop or server) to the configuration
user_invocable: true
---

# Add a New Machine

The user wants to add a new NixOS machine to the configuration.

## Steps

1. Ask the user for:
   - Machine hostname
   - Machine type: **desktop** (imports `modules/nixos/common` + `modules/nixos/desktop`) or **server** (imports `modules/nixos/common` only)
   - Any hardware-specific nixos-hardware module (check https://github.com/NixOS/nixos-hardware)
   - Any host-specific features to configure

2. Create `hosts/<hostname>/configuration.nix`:
   - **Desktop**: import both `../../modules/nixos/common` and `../../modules/nixos/desktop` — common provides base config, desktop adds Plasma, home-manager desktop, user packages, audio, fonts, etc.
   - **Server**: import `../../modules/nixos/common` — base only, no desktop config
   - Set `networking.hostName`
   - Set `system.stateVersion` to the current NixOS version
   - Add host-specific config

3. Create or copy `hosts/<hostname>/hardware-configuration.nix` (usually generated on the target machine with `nixos-generate-config`)

4. Add the `nixosConfigurations.<hostname>` entry in `flake.nix` via the `mkHost` helper:
   - `mkHost` already wires `system`, `specialArgs`, `home-manager.nixosModules.home-manager`, and the `unstable-packages` overlay. Don't repeat them.
   - For **desktops**, follow `framework-gab` / `desktop-gab`: pass `extraModules = [ ./hosts/<hostname>/configuration.nix nixos-hardware.nixosModules.<board> catppuccin.nixosModules.catppuccin ]`.
   - For **servers**, follow `srv-1`: pass `extraModules = [ disko.nixosModules.disko agenix.nixosModules.default ./hosts/<hostname>/configuration.nix ]`. Add `extraOverlays = [ ... ]` if needed. Omit `catppuccin.nixosModules.catppuccin` unless you want NixOS-level theming (home-manager's catppuccin is already wired via gaugendre).

5. Verify: `nixos-rebuild dry-build --flake .#<hostname>`

## Patterns to know

- **Identity**: shared `fullName` / `email` live in `lib/identity.nix`. Import via `let identity = import .../lib/identity.nix in ...` instead of hardcoding.
- **Host-specific network values (srv-1)**: declared in `hosts/srv-1/network-vars.nix` as typed options `host.network.{ipv6,ipv6gw,interface,tailscaleIp}`. Read via `config.host.network.*`. If a new server needs similar values, copy this module pattern.
- **srv-1 services aggregation**: services are imported via `hosts/srv-1/services/default.nix`. To add a service, drop a new `.nix` file in `services/` and add it to that `default.nix`.
- **Caddy internal vhosts**: `import internal` is sufficient — the `(internal)` snippet handles both `bind ${config.host.network.tailscaleIp}` and the IP-based ACL.

## Key Files Reference

- `modules/nixos/common/` — Base config for ALL machines
  - `default.nix` — Entry point (imports save-disk, home-manager, users)
  - `users.nix` — Common user definition (gaugendre + root), SSH keys, passwordless sudo
  - `home-manager.nix` — Base HM config for gaugendre + root
  - `save-disk.nix` — Garbage collection, store optimization
- `modules/nixos/desktop/` — Desktop machines (does NOT import common, hosts import both)
  - `default.nix` — Entry point (imports locale, fonts, audio, iphone, boot, docker, plasma, desktop HM, users, vpn, uv-python, nrfconnect, flatpak). Also holds the desktop packages (Kate, FreeCAD, etc.), Firefox, Steam, KDE Connect
  - `users.nix` — Desktop user groups (`networkmanager`, `dialout`)
  - `home-manager.nix` — Desktop HM additions (imports `modules/home/gaugendre/desktop/`)
  - `plasma.nix` — Plasma/SDDM desktop environment
  - `virt.nix` — Virtualization (KVM/libvirt) — NOT imported by default, host must import explicitly
- `modules/home/shared/` — CLI tools shared by ALL users (fish, bat, eza, starship, helix, fresh). Imported by both gaugendre and root.
- `modules/home/gaugendre/home.nix` — Base user config (all machines). Imports `../shared`, `./git.nix`.
- `modules/home/gaugendre/desktop/` — Desktop home-manager (krunner-autostart, konsole, kwallet-ssh, email, zed, vscode, plasma, rust, go, lua, devenv, ai-agents)
- `modules/home/gaugendre/desktop/ai-agents.nix` — Claude Code config (gaugendre only, intentionally NOT in `shared/` to keep root minimal).
- `modules/home/root/home.nix` — Root user HM config (imports `../shared` only)
- `lib/identity.nix` — Shared `fullName` / `email` (single source of truth)
