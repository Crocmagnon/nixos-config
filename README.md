# nixos-config

## Directory Structure

- **`hosts/`**: Machine-specific configurations. Each subdirectory corresponds to a hostname (e.g., `framework-gab`, `srv-1`) and contains the entry point (`configuration.nix`) for that system.
- **`modules/`**:
    - **`modules/nixos/common/`**: Base config for **all** machines (nix settings, fish, basic packages, users, home-manager setup)
    - **`modules/nixos/desktop/`**: Config for **desktop machines only** (Plasma, audio, fonts, locale, boot, docker, vpn, uv-python, desktop users, desktop home-manager)
    - **`modules/home/gaugendre/`**: User-specific Home Manager configuration entry point.
    - **`modules/home/gaugendre/desktop/`**: Home Manager modules for **desktop machines only** (konsole, email, zed, vscode, krunner).
    - **`modules/home/shared/`**: Reusable Home Manager modules shared across **all** machines (shell, editor, prompt).
    - **`modules/home/root/`**: Root user Home Manager configuration.
- **`overlays/`**: Custom Nixpkgs overlays to modify or extend packages.

## Module Hierarchy

### All machines
```
modules/nixos/common/
  default.nix → save-disk.nix, home-manager.nix, users.nix
                                → modules/home/gaugendre/home.nix (base: CLI tools, git, ssh, gpg)
                                → modules/home/shared/ (fish, helix, starship, eza, ai-agents)
                                → modules/home/root/home.nix
```

### Desktop machines (framework-gab, desktop-gab)
```
hosts import both modules/nixos/common and modules/nixos/desktop

modules/nixos/desktop/
  default.nix → locale, fonts, audio, boot, iphone, docker, plasma, vpn, uv-python
              → users.nix (desktop user packages, Firefox, Steam, KDE Connect...)
              → home-manager.nix
                  → modules/home/gaugendre/desktop/ (konsole, email, zed, vscode, krunner)
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
3. Add to `flake.nix`:
    ```nix
    nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/<hostname>/configuration.nix
        # nixos-hardware module if applicable
        catppuccin.nixosModules.catppuccin
        home-manager.nixosModules.home-manager
        {
          nixpkgs.overlays = [
            (import ./overlays/unstable-packages.nix { inherit nixpkgs-unstable; })
          ];
        }
      ];
    };
    ```
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
3. Add to `flake.nix` (same pattern, without catppuccin/nixos-hardware if not needed)
4. Build: `nixos-rebuild dry-build --flake .#<hostname>`

## Update secrets
```
cd hosts/srv-1/secrets
nix run github:ryantm/agenix -- -e miniflux-db.age
```
