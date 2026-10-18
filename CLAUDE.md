# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Deploy: srv-1 fetches the pushed current branch from GitHub and switches itself
mise run srv-1

# Build without switching (dry run; works with the nix from pacman on Arch)
nix build .#nixosConfigurations.srv-1.config.system.build.toplevel --dry-run

# Check flake validity
nix flake check

# Update flake inputs
nix flake update

# Update a single input
nix flake update <input-name>
```

## Secrets Management

Secrets are managed with agenix, in `hosts/srv-1/age` (system-level, decrypted at
boot with the host SSH key).

The directory is named `age/`, not `secrets/`: Claude Code refuses to read
anything under a path segment called `secrets`, which blocked reading the rules
file itself. `.claude/settings.json` denies what actually matters instead --
running `age`/`agenix` and reading `*.age`.

```bash
cd hosts/srv-1/age
agenix -e <secret-name>.age

# After changing recipients
agenix -r
```

`hosts/srv-1/age/default.nix` derives `age.secrets` from `secrets.nix` by
`mapAttrs'`, so adding a server secret is one rule + one `agenix -e`, no module
edit.

The desktops run Arch: there `agenix` is the fish function `agenix` from the
dotfiles repo (`nix run --inputs-from <this repo> agenix`, nix from pacman), which
forces `-i ~/.config/agenix/identity.txt`: the CLI has no env var or config file
for the identity, and `~/.ssh/id_ed25519` has a passphrase age cannot get from
kwallet. That passphrase-less age key (`age-keygen`; deployed by the dotfiles
repo, git-crypt-encrypted as
`dot_config/private_agenix/encrypted_private_identity.txt`, also in Bitwarden) is
a recipient of the srv-1 store. The SSH keys stay recipients as a fallback
(`agenix -i ~/.ssh/id_ed25519 -e ...` if the age key is lost).

## Automatic Updates

- `.github/workflows/update-flake-lock.yml` runs `nix flake update` every Monday at 03:00 UTC and
  pushes it to the fixed branch `update-flake-lock`, opening the PR `flake.lock: update`. If that
  PR is still open, it adds a commit on top of its branch (fix-up commits are kept, never
  force-pushed); otherwise it restarts the branch from `main`. It pushes with the
  `FLAKE_UPDATE_TOKEN` secret (fine-grained PAT, this repo only, Contents + Pull requests
  read/write): what `GITHUB_TOKEN` pushes triggers no workflow, so `pr-build` would not run.
  When the PAT expires, the job fails on authentication: create a new one and
  `gh secret set FLAKE_UPDATE_TOKEN`.
- `.github/workflows/pr-build.yml` runs on every PR to `main` and every push to it. It builds srv-1
  at the PR base and at the PR merged into `main`, then posts a single, edited-in-place comment:
  `dix` between both runtime closures (~5 GiB from the cache; `dix` on unbuilt `.drv` files
  diffs the *build* closure and drowns the signal), or, if the PR does not build, its `error:`
  lines and the end of the log, and the check goes red. The check is required on `main`, hence
  no paths filter (a skipped required check blocks the PR).
- Typical red check on the weekly PR: a pinned fixed-output hash that a bump invalidates, e.g.
  `caddy.withPlugins` in `hosts/srv-1/services/caddy.nix` on a caddy bump. Copy the `got:` hash
  from the report into the file and push on `update-flake-lock`; `pr-build` reruns.
- `.github/workflows/auto-fix.yml`: when `pr-build` fails on `update-flake-lock`, Claude
  (`anthropics/claude-code-action`, `CLAUDE_CODE_OAUTH_TOKEN` secret from `claude setup-token`,
  valid one year) gets one attempt at a fix. Two jobs: Claude runs with no write credential
  (`persist-credentials: false`, read-only `GITHUB_TOKEN`) and only exact Bash commands (the
  srv-1 `nix build`, `git status`) -- a prefix rule such as `nix eval:*` would allow
  `--expr`/`--option`, i.e. arbitrary code on the runner; its diff goes out as an artifact, and
  a fresh runner applies it and pushes it with the PAT, so `pr-build` rebuilds and reports.
  **One attempt per bump**: only a failed commit that touches nothing but `flake.lock` gets one,
  and only on a run's first attempt -- once a fix (Claude's or yours) is on top, or on a manual
  re-run, nothing happens. It never merges; the required check stays the gate. To trigger it
  again on the same bump, close and reopen the PR.
- `hosts/srv-1/auto-upgrade.nix`: `system.autoUpgrade` applies `github:Crocmagnon/nixos-config`
  (`main`, its committed `flake.lock`, never `--update-input`) every night at 04:00–04:30
  Europe/Paris, after a running restic. **Whatever is on `main` reaches production overnight.**
  A branch tried with `mise run srv-1` is replaced by `main` the next night.
- Reboots only when kernel, initrd or modules change, and only within 04:00–06:00. The module
  always runs `nixos-rebuild boot` first: outside the window (e.g. restic ran past 06:00) the new
  generation becomes the boot default but is **not activated**, and the unit still succeeds
  ("Outside of configured reboot window, skipping." in the journal, also in the healthchecks
  ping body). The next reboot -- the next in-window night, or any manual or provider reboot --
  applies it. If that happens every night, srv-1 silently stops updating with green pings:
  compare `readlink /run/booted-system/kernel` with `readlink /nix/var/nix/profiles/system/kernel`.
- Reported to healthchecks as `nixos-upgrade` (start/success/failure, like restic). The check is
  created by the first run; its period (1 day) and grace are set by hand in the healthchecks UI.

## Architecture

This is a NixOS flake configuration for a single machine, **srv-1** (server, uses
disko for disk management, agenix for secrets). The former desktops
(framework-gab, desktop-gab) now run Arch and are configured elsewhere.

### Module Hierarchy

**System-level** (`modules/nixos/common/`): base config (nix settings, fish, basic packages, home-manager setup)
- `default.nix` → Entry point, imports `save-disk.nix`, `home-manager.nix`, `users.nix`
- `users.nix` → User definition (gaugendre + root), SSH keys, passwordless sudo
- `home-manager.nix` → HM config for gaugendre + root

**Home-manager** (`modules/home/`):
- `gaugendre/home.nix` → User config (imports `shared/`, `git.nix`)
- `shared/` → Reusable modules for both users (fish, bat, eza, starship, helix, fresh, theme-auto) — imported by both gaugendre and root
- `root/home.nix` → Root user HM config

**Shared helpers** (`lib/`):
- `identity.nix` → Single source of truth for `fullName` / `email`. Imported via `let identity = import .../lib/identity.nix` in git, Caddy ACME, etc.

**Host-specific** (`hosts/srv-1/`):
- `configuration.nix` → Entry point, imports hardware + `modules/nixos/common`
- `network-vars.nix` → Declares `host.network.{ipv6,ipv6gw,interface,tailscaleIp}` options (typed, via `lib.mkOption`). Consumed by `network.nix` and Caddy vhosts as `config.host.network.*`.
- `services/default.nix` → Aggregates all service imports. `configuration.nix` just imports `./services`.

### Key Patterns

- Home-manager is configured via `modules/nixos/common/home-manager.nix` with `useGlobalPkgs = true`
- srv-1 does **not** load `catppuccin.nixosModules.catppuccin` at the NixOS level (only the home-manager module, for gaugendre and root).
- The **terminal** stack does not use the fixed `lib/catppuccin.nix` flavor: it follows the light/dark theme of the terminal the SSH session comes from, at runtime. fish, bat and claude detect it themselves; a fish hook (`__theme_auto`, registered on `--on-variable fish_terminal_color_theme`) drives starship, eza and helix. The shared logic lives in `modules/home/shared/theme-auto.nix`. Each replaced upstream module is switched off individually (`catppuccin.{fish,bat,starship,eza,helix}.enable = false`). `lib/catppuccin.nix` stays `latte` as the fallback whenever the terminal does not answer. See `docs/superpowers/specs/2026-09-18-terminal-theme-auto-switch-design.md`.
- helix needs `editor.true-color = true`: `COLORTERM` is not forwarded over SSH and the `xterm-256color` terminfo does not advertise RGB, so on srv-1 helix silently rejected every Catppuccin theme and fell back to its default one.
- helix's theme name is the constant `catppuccin`; `~/.config/helix/themes/catppuccin.toml` only holds an `inherits` line and is **not** managed by home-manager (a `home.activation` seeds it). `SIGUSR1` makes helix re-read `config.toml` and re-apply the theme *named* there, discarding any runtime `:theme`, which is why the indirection lives in the file rather than the name.
- `calme-{latte,mocha}` (`modules/home/shared/helix-themes/`) are installed but **not** the default — the `theme-auto.nix` hook points at `catppuccin-*`; reach them with `:theme calme-latte`. They are catppuccin reorganised along <https://tonsky.me/blog/syntax-highlighting/>: only strings, constants, comments and the keyword that *introduces* a definition get a colour, everything else falls back to the text colour. They `inherits` the `catppuccin-*` themes — which must therefore stay installed — and override nothing but the syntax section, so UI chrome, markdown markup and diff colours are still catppuccin's. Helix exposes no `@function.definition` capture (no query has one), so a theme cannot tell a definition from a call: `keyword.function` (`fn`, `def`, `lambda`, `func`, closures included) is what marks a definition instead. `class`, `trait`, `impl` and go's `type` sit in the catch-all `@keyword` alongside `pub`/`global`/`as` and are out of reach without patching the queries. In latte the comment background carries the signal rather than the foreground (catppuccin's `yellow` on a pale yellow background would sit at ~2:1 contrast), which also means `cursorline` is hidden on comment lines.
- `overlays/unstable-packages.nix` replaces a fixed list of packages (btop, esphome, gh, mise…) by their nixpkgs-unstable version, under their usual `pkgs.<package>` name. To get another one from unstable, add it to that list.
- `flake.nix` uses a local `mkHost` helper to factor common modules (`home-manager`, `unstable-packages` overlay). The host only declares its `extraModules` and `extraOverlays`.

### Caddy Internal Access (srv-1)

To restrict a Caddy virtualHost to internal/Tailscale access, `import internal` in the virtualHost's `extraConfig` is sufficient. The `(internal)` snippet (defined in `hosts/srv-1/services/caddy.nix`) handles both:

1. `bind ${config.host.network.tailscaleIp}` — listen only on the Tailscale interface
2. IP-based access control via `client_ip` matcher (private ranges + Tailscale CGNAT)

Both are required: without `bind`, Caddy still listens on all interfaces even though the IP filter would reject external requests. Both live in the snippet so a vhost cannot import only one half.
