#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile=${1:-yunhao}

if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [[ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

command -v nix >/dev/null || {
  echo "Nix is not installed. Run scripts/deploy-remote.sh from an existing machine." >&2
  exit 1
}

export NIX_CONFIG='experimental-features = nix-command flakes'
generation=$(nix build \
  --no-link \
  --print-out-paths \
  "path:$repo#homeConfigurations.${profile}.activationPackage")
"$generation/activate"

systemctl --user daemon-reload
systemctl --user reset-failed dms.service 2>/dev/null || true
systemctl --user restart dms.service

echo "Applied Home Manager profile: $profile"
