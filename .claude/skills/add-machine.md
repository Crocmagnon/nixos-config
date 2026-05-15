---
description: Add a new NixOS machine (desktop or server) to the configuration
user_invocable: true
---

# Add a New Machine

The user wants to add a new NixOS machine to the configuration.

## Steps

1. Ask the user for:
   - Machine hostname
   - Machine type: **desktop** (imports `modules/nixos/desktop`) or **server** (imports `modules/nixos/common` only)
   - Any hardware-specific nixos-hardware module (check https://github.com/NixOS/nixos-hardware)
   - Any host-specific features to configure

2. Create `hosts/<hostname>/configuration.nix`:
   - **Desktop**: import `../../modules/nixos/desktop` — this brings in everything (Plasma, home-manager desktop, user, packages, audio, fonts, etc.)
   - **Server**: import `../../modules/nixos/common` — base only, no desktop config
   - Set `networking.hostName`
   - Set `system.stateVersion` to the current NixOS version
   - Add host-specific config

3. Create or copy `hosts/<hostname>/hardware-configuration.nix` (usually generated on the target machine with `nixos-generate-config`)

4. Add the `nixosConfiguration.<hostname>` entry in `flake.nix`:
   - For desktops, follow the pattern of `framework-gab` or `desktop-gab`
   - For servers, follow the pattern of `srv-1`
   - Include appropriate modules: `catppuccin.nixosModules.catppuccin`, `home-manager.nixosModules.home-manager`, hardware module, overlays

5. Verify: `nixos-rebuild dry-build --flake .#<hostname>`

## Key Files Reference

- `modules/nixos/common/` — Base config for ALL machines
  - `default.nix` — Entry point (imports save-disk + home-manager)
  - `home-manager.nix` — Base HM config for gaugendre + root
  - `save-disk.nix` — Garbage collection, store optimization
- `modules/nixos/desktop/` — Desktop machines (imports common + all desktop features)
  - `default.nix` — Entry point (imports common + locale, fonts, audio, boot, docker, plasma, user, vpn, uv-python, desktop HM)
  - `user.nix` — Desktop user definition, packages, sudo, Firefox, Steam, KDE Connect
  - `home-manager.nix` — Desktop HM additions (imports `home/desktop/`)
  - `plasma.nix` — Plasma/SDDM desktop environment
  - `virt.nix` — Virtualization (KVM/libvirt) — NOT imported by default, host must import explicitly
- `home/shared/` — CLI tools for all machines (fish, helix, starship, eza, ai-agents)
- `home/desktop/` — Desktop home-manager (konsole, email, zed, vscode, krunner)
- `home/gaugendre/home.nix` — Base user config (all machines)
