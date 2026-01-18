# nixos-config

## Directory Structure

- **`hosts/`**: Machine-specific configurations. Each subdirectory corresponds to a hostname (e.g., `framework-gab`, `srv-1`) and contains the entry point (`configuration.nix`) for that system.
- **`modules/`**:
    - **`modules/nixos/`**: Shared NixOS modules and configurations that can be imported by multiple hosts. These are system-level settings (e.g., common packages, services).
- **`home/`**: Home Manager configurations.
    - **`home/<user>/`**: User-specific configuration entry points.
    - **`home/shared/`**: Reusable Home Manager modules and dotfiles (e.g., shell config, editor settings) shared across users.
- **`overlays/`**: Custom Nixpkgs overlays to modify or extend packages.

## Update secrets
```
cd hosts/srv-1/secrets
nix run github:ryantm/agenix -- -e miniflux-db.age
```
