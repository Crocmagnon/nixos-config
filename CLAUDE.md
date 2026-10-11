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

The directories are named `age/`, not `secrets/`: Claude Code refuses to read
anything under a path segment called `secrets`, which blocked reading the rules
files themselves. `.claude/settings.json` denies what actually matters instead --
running `age`/`agenix` and reading `*.age`.

```bash
# srv-1 (system-level, decrypted at boot with the host SSH key)
cd hosts/srv-1/age
agenix -e <secret-name>.age

# desktops (home-manager module, decrypted in the user session ->
# $XDG_RUNTIME_DIR/agenix/).
cd modules/home/gaugendre/desktop/age
agenix -e <secret-name>.age

# After changing recipients: `agenix -r` in EACH of the three rules directories
# (hosts/srv-1/age, .../desktop/age, .../desktop/age/fonts) -- the fonts rules
# file is standalone, the parent one does not reference it.
agenix -r
```

`hosts/srv-1/age/default.nix` derives `age.secrets` from `secrets.nix` by
`mapAttrs'`, so adding a server secret is one rule + one `agenix -e`, no module
edit. Desktop secrets are declared in the module that consumes them.

`agenix` on desktops is a wrapper (`modules/home/gaugendre/desktop/agenix.nix`)
around the flake's pinned agenix, forcing `-i ~/.config/agenix/identity.txt`: the
CLI has no env var or config file for the identity, and `~/.ssh/id_ed25519` has a
passphrase age cannot get from kwallet. That same passphrase-less age key
(`age-keygen`, never committed -- **back it up**) is a recipient of both stores and
is what the user-session systemd services decrypt with (`age.identityPaths`, set
once in `agenix.nix` for all desktop modules). The SSH keys stay recipients as a
fallback (`agenix -i ~/.ssh/id_ed25519 -e ...` if the age key is lost).

`age/fonts/` is a third rules file holding the licensed OTFs. It is a separate
file (so it needs its own `agenix -r`) but its recipients are the parent's, read
back out of it -- one list to maintain.

Updating an **existing** font needs no `age` by hand: when stdin isn't a TTY agenix
swaps its editor for `cp -- /dev/stdin`, which is binary-safe.

```bash
cd modules/home/gaugendre/desktop/age/fonts
agenix -e ComicCode-Bold.otf.age < ~/Downloads/ComicCode-Bold.otf
agenix -d ComicCode-Bold.otf.age > /tmp/ComicCode-Bold.otf
```

Adding a **new** font is the chicken-and-egg case: `secrets.nix` derives its rules
from `readDir`, so the rule only exists once the `.age` does, and `agenix -e` on a
name with no rule fails. Create that first file with `age` directly, then agenix
owns it:

```bash
nix eval --raw --impure \
  --expr 'builtins.concatStringsSep "\n" (import ./../secrets.nix)."ro-github-token.age".publicKeys' \
  | age -R - -o NewFont.otf.age ~/Downloads/NewFont.otf
```

`fonts.nix` picks up any `*.age` in the directory by `readDir`, so that single file
is the whole change -- no module edit. `agenix -r` rekeys binaries fine.

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
- The **terminal** stack does not use the fixed `lib/catppuccin.nix` flavor: it follows the system light/dark theme at runtime. kitty reads the XDG portal and applies `~/.config/kitty/*-theme.auto.conf`; herdr relays OSC 11 to pane children; fish, bat and claude detect it themselves; a fish hook (`__theme_auto`, registered on `--on-variable fish_terminal_color_theme`) drives starship, eza and helix. The shared logic lives in `modules/home/shared/theme-auto.nix` — that placement is deliberate, and is why SSH sessions to srv-1 follow too. Each replaced upstream module is switched off individually (`catppuccin.{kitty,fish,bat,starship,eza,helix}.enable = false`). `lib/catppuccin.nix` stays `latte` as the fallback for everything else (zed, vscode, thunderbird, plymouth, sddm) and whenever the terminal does not answer. See `docs/superpowers/specs/2026-09-18-terminal-theme-auto-switch-design.md`.
- helix needs `editor.true-color = true`: `COLORTERM` is not forwarded over SSH and the `xterm-256color` terminfo does not advertise RGB, so on srv-1 helix silently rejected every Catppuccin theme and fell back to its default one.
- helix's theme name is the constant `catppuccin`; `~/.config/helix/themes/catppuccin.toml` only holds an `inherits` line and is **not** managed by home-manager (a `home.activation` seeds it). `SIGUSR1` makes helix re-read `config.toml` and re-apply the theme *named* there, discarding any runtime `:theme`, which is why the indirection lives in the file rather than the name.
- `calme-{latte,mocha}` (`modules/home/shared/helix-themes/`) are installed but **not** the default — the `theme-auto.nix` hook points at `catppuccin-*`; reach them with `:theme calme-latte`. They are catppuccin reorganised along <https://tonsky.me/blog/syntax-highlighting/>: only strings, constants, comments and the keyword that *introduces* a definition get a colour, everything else falls back to the text colour. They `inherits` the `catppuccin-*` themes — which must therefore stay installed — and override nothing but the syntax section, so UI chrome, markdown markup and diff colours are still catppuccin's. Helix exposes no `@function.definition` capture (no query has one), so a theme cannot tell a definition from a call: `keyword.function` (`fn`, `def`, `lambda`, `func`, closures included) is what marks a definition instead. `class`, `trait`, `impl` and go's `type` sit in the catch-all `@keyword` alongside `pub`/`global`/`as` and are out of reach without patching the queries. In latte the comment background carries the signal rather than the foreground (catppuccin's `yellow` on a pale yellow background would sit at ~2:1 contrast), which also means `cursorline` is hidden on comment lines.
- A running kitty will not pick up a **content** change to a theme file across a rebuild: `ThemeColors.refresh()` only re-reads when the mtime grows, and nix store mtimes are fixed. Restart kitty after a rebuild that changes theme content. Flavor switching itself is live.
- `overlays/unstable-packages.nix` replaces a fixed list of packages (btop, uv, claude-code, gopls, koreader…) by their nixpkgs-unstable version, under their usual `pkgs.<package>` name. To get another one from unstable, add it to that list.
- `nh os switch .` is the preferred rebuild command (wraps nixos-rebuild with niceties)
- Proprietary AppImages (`rotatrix.nix`) are packaged with a fixed-output `runCommand` that curls the vendor URL + `appimageTools.wrapType2`. The binary and the license-gated download key are never committed (public repo); the key sits in `/etc/rotatrix-key` and reaches the builder through `nix.settings.extra-sandbox-paths` — see "Proprietary AppImages" in `README.md`. `wrapType2` only symlinks the binary, so the `.desktop` and icons must be installed by hand via `extraInstallCommands` (pull them out with `appimageTools.extract`).
- udev: `services.udev.extraRules` lands in `/etc/udev/rules.d/99-local.rules`, which runs **after** systemd's `73-seat-late.rules`, so a `TAG+="uaccess"` there is silently ignored. Use `GROUP`/`MODE` (`rotatrix.nix`), or ship a rules file numbered below 70 via `services.udev.packages` (`nrfconnect.nix`). The `plugdev` group does not exist on NixOS.
- Autostart of a **graphical** app: install its `.desktop` into `$out/etc/xdg/autostart` (`/etc/xdg/autostart` is in `environment.pathsToLink`, so it lands in `/run/current-system/sw/etc/xdg/autostart`), not a `systemd.user.services` unit on `graphical-session.target` — that unit starts before Plasma has published `DISPLAY`/`WAYLAND_DISPLAY` into the user systemd manager, which breaks anything touching X (cost us a `pynput` `ImportError` in `rotatrix.nix`). A systemd user unit is still right for a display-less daemon (`modules/home/gaugendre/desktop/krunner-autostart.nix`).
- OpenClaw (`hosts/srv-1/services/openclaw.nix`): `openclaw.json` is generated by Nix and **copied** into `/var/lib/openclaw` at every start (the Gateway rewrites its file and rejects symlinks), so a change made from the Control UI or `openclaw config set` is lost at restart — make it in Nix. The copy first deletes `openclaw.json.bak*`: against that baseline, a much smaller file or one without `meta` is treated as clobbered and the backup restored over it. Secrets are SecretRefs to the container environment (`openclaw-env.age`); the doctor flags a `"${VAR}"` string as a plaintext secret, so `"${VAR}"` is only used where the schema takes no SecretRef. The OVH key still ends up in `state/openclaw.sqlite` (auth profile). The Gateway holds a 5 min lease on its state: it is only reclaimed from a dead process under the same hostname, hence `--hostname=openclaw`, and `--stop-timeout=60` so a stop does not SIGKILL it first. Agent egress is limited to Internet + Caddy:443 by the `openclaw-egress` chain (table `mangle`, so netavark's own rules cannot jump ahead of it). The container `bindsTo` `firewall.service` and its `preStart` refuses to start without the jump to that chain. The `preStart` seeds the agent-owned skill under the agent's UID (`setpriv`), never as root: the workspace is the agent's, a symlink there would redirect a root `mkdir`/`chown`. Pair a new browser or phone with `sudo podman exec openclaw openclaw devices list` / `devices approve <id>`; check config keys with `openclaw config schema`.
- `flake.nix` uses a local `mkHost` helper to factor common modules (`home-manager`, `unstable-packages` overlay). Hosts only declare their `extraModules` (and `extraOverlays` for srv-1).

### Caddy Internal Access (srv-1)

To restrict a Caddy virtualHost to internal/Tailscale access, `import internal` in the virtualHost's `extraConfig` is sufficient. The `(internal)` snippet (defined in `hosts/srv-1/services/caddy.nix`) handles both:

1. `bind ${config.host.network.tailscaleIp}` — listen only on the Tailscale interface
2. IP-based access control via `client_ip` matcher (private ranges + Tailscale CGNAT)

Both are required: without `bind`, Caddy still listens on all interfaces even though the IP filter would reject external requests. Both live in the snippet so a vhost cannot import only one half.

`(internal)` also refuses the OpenClaw agent's podman subnet
(`config.host.network.agentSubnet`), which `private_ranges` would otherwise let
through. A vhost the agent may reach imports `internal_agent` instead — same
`bind` and IP filter, without that refusal. Both build on `(internal_base)`.
The agent's egress (Internet + Caddy:443 only) is in `hosts/srv-1/services/openclaw.nix`.
