#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

sync_tree() {
  local source_dir=$1
  local target_dir=$2
  shift 2
  mkdir -p "$target_dir"
  rsync -a --delete \
    --exclude='*.bak' \
    --exclude='*.backup*' \
    --exclude='*.old' \
    "$@" \
    "$source_dir/" "$target_dir/"
}

sync_tree "$HOME/.config/niri" "$repo/config/niri"
sync_tree "$HOME/.config/ghostty" "$repo/config/ghostty"
sync_tree "$HOME/.config/fcitx5" "$repo/config/fcitx5" \
  --exclude='cached_layouts' --exclude='profile_*'

mkdir -p "$repo/config/DankMaterialShell" "$repo/config/shell"
rsync -a \
  "$HOME/.config/DankMaterialShell/settings.json" \
  "$HOME/.config/DankMaterialShell/firefox.css" \
  "$repo/config/DankMaterialShell/"
rsync -a "$HOME/.config/starship.toml" "$repo/config/shell/starship.toml"

# Nix supplies these commands; do not bind the config to Cargo or one home path.
sed -i \
  -e 's|/home/yunhao/.cargo/bin/nirius|nirius|g' \
  -e 's|/home/yunhao/.cargo/bin/niriusd|niriusd|g' \
  "$repo/config/niri/config.kdl" \
  "$repo/config/niri/dms/binds.kdl"

echo "Captured workstation configuration in $repo/config"
echo "Review with: git -C $repo diff"
