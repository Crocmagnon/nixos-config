# nixos-config

## Directory Structure

- **`hosts/`**: Machine-specific configurations. Each subdirectory corresponds to a hostname (e.g., `framework-gab`, `srv-1`) and contains the entry point (`configuration.nix`) for that system.
- **`modules/`**:
    - **`modules/nixos/common/`**: Base config for **all** machines (nix settings, fish, basic packages, users, home-manager setup)
    - **`modules/nixos/desktop/`**: Config for **desktop machines only** (Plasma, audio, fonts, locale, iphone, boot, docker, vpn, uv-python, nrfconnect, rotatrix, desktop packages, desktop users, desktop home-manager)
    - **`modules/home/gaugendre/`**: User-specific Home Manager configuration entry point.
    - **`modules/home/gaugendre/desktop/`**: Home Manager modules for **desktop machines only** (krunner-autostart, konsole, kwallet-ssh, email, zed, vscode, plasma, rust, go, lua, devenv, ai-agents).
    - **`modules/home/shared/`**: Reusable Home Manager modules shared across **all** users (fish, bat, eza, starship, helix, fresh).
    - **`modules/home/root/`**: Root user Home Manager configuration.
- **`lib/`**: Shared helpers — `identity.nix` exposes `fullName` / `email` as a single source of truth (consumed by git, email account, Caddy ACME).
- **`overlays/`**: Custom Nixpkgs overlays to modify or extend packages.

## Module Hierarchy

### All machines
```
modules/nixos/common/
  default.nix → save-disk.nix, home-manager.nix, users.nix
                                → modules/home/gaugendre/home.nix (base: CLI tools, git, ssh, gpg)
                                  → modules/home/shared/ (fish, bat, eza, starship, helix, fresh)
                                → modules/home/root/home.nix
                                  → modules/home/shared/ (fish, bat, eza, starship, helix, fresh)
```

### Desktop machines (framework-gab, desktop-gab)
```
hosts import both modules/nixos/common and modules/nixos/desktop

modules/nixos/desktop/
  default.nix → locale, fonts, audio, iphone, boot, docker, plasma, vpn, uv-python, nrfconnect,
                rotatrix
              → desktop packages (Kate, PrusaSlicer...), Firefox, Steam, KDE Connect
              → users.nix (desktop user groups: networkmanager, dialout)
              → home-manager.nix
                  → modules/home/gaugendre/desktop/ (krunner-autostart, konsole, kwallet-ssh,
                    email, zed, vscode, plasma, rust, go, lua, devenv,
                    ai-agents (Claude Code, gaugendre only))
```

### Server (srv-1)
```
modules/nixos/common/ only → no desktop config leaks in
```

## Adding a New Machine

### New Desktop

1. Create `hosts/<hostname>/hardware-configuration.nix` (generate on target with `nixos-generate-config`)
2. Create `hosts/<hostname>/configuration.nix`:
    ```nix
    { ... }:
    {
      imports = [
        ./hardware-configuration.nix
        ../../modules/nixos/common
        ../../modules/nixos/desktop
      ];
      networking.hostName = "<hostname>";
      # Host-specific config here (e.g., fingerprint reader, GPU, cooling)
      system.stateVersion = "25.11";
    }
    ```
3. Add to `flake.nix` via the `mkHost` helper:
    ```nix
    nixosConfigurations.<hostname> = mkHost {
      extraModules = [
        ./hosts/<hostname>/configuration.nix
        # nixos-hardware.nixosModules.<board> if applicable
        catppuccin.nixosModules.catppuccin
      ];
    };
    ```
    `mkHost` already wires `home-manager`, `system`, `specialArgs`, and the `unstable-packages` overlay. Pass `extraOverlays = [ ... ]` if you need additional overlays.
4. Build: `nixos-rebuild dry-build --flake .#<hostname>`

### New Server

1. Create `hosts/<hostname>/hardware-configuration.nix`
2. Create `hosts/<hostname>/configuration.nix`:
    ```nix
    { ... }:
    {
      imports = [
        ./hardware-configuration.nix
        ../../modules/nixos/common
      ];
      networking.hostName = "<hostname>";
      # Server-specific config (services, users, etc.)
      system.stateVersion = "25.11";
    }
    ```
3. Add to `flake.nix` via `mkHost` (omit `catppuccin.nixosModules.catppuccin` unless you want NixOS-level theming):
    ```nix
    nixosConfigurations.<hostname> = mkHost {
      extraModules = [
        ./hosts/<hostname>/configuration.nix
        # disko.nixosModules.disko, agenix.nixosModules.default if needed
      ];
    };
    ```
4. Build: `nixos-rebuild dry-build --flake .#<hostname>`

## Update secrets
```
cd hosts/srv-1/secrets
nix run github:ryantm/agenix -- -e miniflux-db.age
```

## Proprietary AppImages

Some desktop apps aren't in nixpkgs and are only distributed as a license-gated AppImage
(currently: Rotatrix, `modules/nixos/desktop/rotatrix.nix`). The binary is **not** committed —
this repository is public, and a 207 MB blob would sit in the git history forever. Instead the
module uses `pkgs.requireFile`, so the repo only holds a filename and a sha256, and the binary is
registered in the Nix store manually.

That registration is needed **once per machine, and again after every version bump**:

```
# 1. download the AppImage (Rotatrix: https://rotatrix.com/instructions/, needs the license key)
# 2. register it, keeping the original filename — it's part of the store path
nix-store --add-fixed sha256 ~/Downloads/Rotatrix-linux-x86_64.AppImage
```

On a version bump, also update `version` and `hash` in the module:

```
nix hash file --sri ~/Downloads/Rotatrix-linux-x86_64.AppImage
```

`nix flake check` and evaluation still work on a machine where the file isn't registered — only
building the package needs it.

Rotatrix installs its FreeCAD addon by copying it out of the extracted AppImage, so it lands in
`~/.local/share/FreeCAD/v1-1/Mod/rotatrix_freecad` with the store's read-only permissions (dir
mode 555). It cannot overwrite that on a version bump — delete the directory before first launch
of the new version so the addon gets reinstalled.

## Pre-commit hooks

Nix files are auto-formatted with `nixfmt` via a [prek](https://github.com/j178/prek) hook (drop-in replacement for `pre-commit`). After cloning, install the git hook once:

```
prek install
```

Run the hooks manually on all files:

```
prek run --all-files
```
