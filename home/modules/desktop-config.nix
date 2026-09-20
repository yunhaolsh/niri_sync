{ config, lib, pkgs, ... }:

let
  snapshot = ../../config;
in {
  # The Ubuntu Niri package globally enables Waybar. DMS supplies the bar here.
  home.file.".config/systemd/user/waybar.service" = {
    force = true;
    source = config.lib.file.mkOutOfStoreSymlink "/dev/null";
  };

  # DMS and Fcitx modify their config at runtime, so deploy writable snapshots
  # instead of immutable symlinks into the Nix store.
  home.activation.installWorkstationConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    sync_tree() {
      source_dir=$1
      target_dir=$2
      if [ -d "$source_dir" ]; then
        mkdir -p "$target_dir"
        ${pkgs.rsync}/bin/rsync -a --chmod=u+rwX "$source_dir/" "$target_dir/"
      fi
    }

    sync_tree ${snapshot}/niri "$HOME/.config/niri"
    sync_tree ${snapshot}/DankMaterialShell "$HOME/.config/DankMaterialShell"
    sync_tree ${snapshot}/ghostty "$HOME/.config/ghostty"
    sync_tree ${snapshot}/fcitx5 "$HOME/.config/fcitx5"
    sync_tree ${snapshot}/shell "$HOME/.config/nix-workstation-shell"

    if [ -f "$HOME/.config/nix-workstation-shell/starship.toml" ]; then
      install -Dm644 \
        "$HOME/.config/nix-workstation-shell/starship.toml" \
        "$HOME/.config/starship.toml"
    fi
  '';
}
