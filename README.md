# Nix-managed Niri workstation

This repository is the source of truth for yunhao's Ubuntu Niri workstations.
Home Manager installs user packages and services, while the repository keeps
writable snapshots for applications that modify their own configuration.

## What Nix manages

- DankMaterialShell 1.4.6, Quickshell, dsearch, and Mesa/EGL integration
- DMS and Waybar user-service policy
- nirius, Starship, Atuin, pyenv, zoxide, Git, and common CLI tools
- Niri, DMS, Ghostty, Fcitx5, and Starship configuration snapshots
- Shell initialization and Fcitx5/Wayland environment variables

Ubuntu still owns system-level packages such as Niri, Ghostty, Fcitx5, the
display manager, GPU firmware, and portals. The remote deploy script installs
the required Ubuntu Fcitx5 packages, but expects Niri and Ghostty to have been
installed for the OS already.

## First deployment to another machine

Run this from an already configured machine:

```bash
./scripts/deploy-remote.sh yunhao@10.109.169.180
```

The script reuses `~/.ssh/id_ed25519_niri_migration` when present. If Mihomo is
listening on local port 7890, Nix downloads on the target automatically use an
SSH reverse proxy. It installs single-user Nix when needed, uploads this repo,
activates Home Manager, restarts DMS, and runs the health check.

The compatibility command below performs the same deployment:

```bash
./install-target-deps.sh yunhao@10.109.169.180
```

## Apply on the current machine

After cloning this repository and installing Nix:

```bash
./scripts/apply-local.sh
```

Use the source-workstation profile when host-specific overrides are needed:

```bash
./scripts/apply-local.sh 'yunhao@legion'
```

## Publish a desktop adjustment

After changing DMS, Niri, Ghostty, Fcitx5, or Starship through their normal UI:

```bash
./scripts/capture-config.sh
git diff
git add .
git commit -m "Update workstation configuration"
git push
```

On another device, pull and apply:

```bash
git pull --ff-only
./scripts/apply-local.sh
```

## Migrate local Codex conversations

Codex conversations are local state and are not managed by Home Manager. Close
Codex completely on both machines, then run this from the source machine:

```bash
./scripts/migrate-codex-state.sh yunhao@new-machine
```

The script backs up the target's existing `~/.codex`, preserves target-local
authentication, copies source sessions and state, merges target rollout files,
and rebuilds the session index. Do not run it while Codex CLI or Desktop is
open on either machine.

Do not commit SSH private keys, tokens, browser profiles, application databases,
or cache directories. Use an age/sops repository or a password manager for
secrets.

## Validation

```bash
nix flake check 'path:.'
./scripts/healthcheck.sh yunhao@10.109.169.180
```

The health check verifies required commands, Niri syntax, DMS service state,
Waybar masking, and graphics-backend errors from the active DMS process.
