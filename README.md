# nixos-config

## Directory Structure

- **`hosts/`**: Machine-specific configurations. Each subdirectory corresponds to a hostname (e.g., `framework-gab`, `srv-1`) and contains the entry point (`configuration.nix`) for that system.
- **`modules/`**:
    - **`modules/nixos/common/`**: Base config for **all** machines (nix settings, fish, basic packages, home-manager setup)
    - **`modules/nixos/desktop/`**: Config for **desktop machines only** (imports common + Plasma, user, audio, fonts, locale, boot, docker, vpn, uv-python, desktop home-manager)
- **`home/`**: Home Manager configurations.
    - **`home/<user>/`**: User-specific configuration entry points.
    - **`home/shared/`**: Reusable Home Manager modules shared across **all** machines (shell, editor, prompt).
    - **`home/desktop/`**: Home Manager modules for **desktop machines only** (email, zed, vscode, krunner).
- **`overlays/`**: Custom Nixpkgs overlays to modify or extend packages.

## Module Hierarchy

### All machines
```
modules/nixos/common/
  default.nix → save-disk.nix, home-manager.nix
                                → home/gaugendre/home.nix (base: CLI tools, git, ssh, gpg)
                                → home/shared/ (fish, helix, starship, eza, ai-agents)
                                → home/root/home.nix
```

### Desktop machines (framework-gab, desktop-gab)
```
modules/nixos/desktop/
  default.nix → common/ (above)
              → locale, fonts, audio, boot, iphone, docker, plasma, vpn, uv-python
              → user.nix (user packages, sudo, Firefox, Steam, KDE Connect...)
              → home-manager.nix
                  → home/desktop/ (konsole, email, zed, vscode, krunner)
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
