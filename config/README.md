# Configuration snapshots

These files are deliberately copied into the target home as writable files.
DMS, Niri, and Fcitx5 generate or update parts of their configuration at
runtime, so immutable Nix-store symlinks are not appropriate here.

Run `scripts/capture-config.sh` after an intentional UI or configuration change.
Backup files, caches, machine-generated Fcitx layouts, and secrets are excluded.
