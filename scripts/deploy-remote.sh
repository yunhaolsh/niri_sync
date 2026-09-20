#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/deploy-remote.sh user@host [profile]"
}

if [[ $# -lt 1 || $# -gt 2 || ${1:-} == -h || ${1:-} == --help ]]; then
  usage
  [[ ${1:-} == -h || ${1:-} == --help ]] && exit 0
  exit 2
fi

target=$1
profile=${2:-yunhao}
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
identity_file=${NIRI_MIGRATION_IDENTITY:-$HOME/.ssh/id_ed25519_niri_migration}
local_proxy_port=${NIRI_MIGRATION_PROXY_PORT:-7890}
remote_proxy_port=${NIRI_MIGRATION_REMOTE_PROXY_PORT:-17890}
remote_dir='.config/nix-workstation'
control_dir=$(mktemp -d "${TMPDIR:-/tmp}/nix-workstation.XXXXXX")
control_socket=$control_dir/control
identity_args=()
forward_args=()
proxy_env=()

[[ -f "$identity_file" ]] && identity_args=(-i "$identity_file")
if ss -ltn 2>/dev/null | grep -qE "[:.]${local_proxy_port}[[:space:]]"; then
  forward_args=(-R "$remote_proxy_port:127.0.0.1:$local_proxy_port")
  proxy_url="http://127.0.0.1:$remote_proxy_port"
  proxy_env=(
    "http_proxy=$proxy_url" "https_proxy=$proxy_url"
    "HTTP_PROXY=$proxy_url" "HTTPS_PROXY=$proxy_url"
  )
  echo "Using SSH reverse proxy through local port $local_proxy_port."
else
  echo "No local proxy detected on port $local_proxy_port; using target networking."
fi

cleanup() {
  ssh -S "$control_socket" -O exit "$target" >/dev/null 2>&1 || true
  rmdir "$control_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

ssh "${identity_args[@]}" \
  -M -S "$control_socket" \
  -o ControlPersist=600 \
  -o ExitOnForwardFailure=yes \
  "${forward_args[@]}" \
  -Nf "$target"
ssh_args=(-S "$control_socket")

remote_home=$(ssh "${ssh_args[@]}" "$target" 'printf %s "$HOME"')
remote_arch=$(ssh "${ssh_args[@]}" "$target" 'uname -m')
[[ $remote_arch == x86_64 ]] || {
  echo "Unsupported target architecture: $remote_arch" >&2
  exit 1
}

apt_packages=(ca-certificates curl xz-utils fcitx5 fcitx5-chinese-addons fcitx5-config-qt fcitx5-frontend-all)
if ssh "${ssh_args[@]}" "$target" \
  "dpkg-query -W -f='\${db:Status-Abbrev}\\n' ${apt_packages[*]} 2>/dev/null | grep -qv '^ii '"; then
  ssh -tt "${ssh_args[@]}" "$target" \
    "sudo apt-get update && sudo apt-get install -y ${apt_packages[*]}"
fi

if ! ssh "${ssh_args[@]}" "$target" \
  '[[ -x /nix/var/nix/profiles/default/bin/nix || -x "$HOME/.nix-profile/bin/nix" ]]'; then
  echo "Installing single-user Nix..."
  printf -v env_prefix '%q ' env -u all_proxy -u ALL_PROXY "${proxy_env[@]}"
  remote_install="set -e; installer=\$(mktemp); ${env_prefix}curl --proto '=https' --tlsv1.2 -fsSL https://nixos.org/nix/install -o \"\$installer\"; ${env_prefix}sh \"\$installer\" --no-daemon; rm -f \"\$installer\""
  printf -v remote_command 'bash --noprofile --norc -c %q' "$remote_install"
  ssh -tt "${ssh_args[@]}" "$target" "$remote_command"
fi

echo "Uploading declarative workstation configuration..."
rsync -a --delete \
  --exclude='.git/' \
  --exclude='result*' \
  --exclude='install-target.log' \
  -e "ssh -S $control_socket" \
  "$repo/" "$target:$remote_home/$remote_dir/"

printf -v remote_env '%q ' env -u all_proxy -u ALL_PROXY "${proxy_env[@]}" \
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
ssh "${ssh_args[@]}" "$target" \
  "${remote_env}bash --noprofile --norc -s" -- "$remote_home/$remote_dir" "$profile" <<'REMOTE'
set -euo pipefail
repo=$1
profile=$2

if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
else
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

mkdir -p "$HOME/.config/nix"
printf '%s\n' 'experimental-features = nix-command flakes' > "$HOME/.config/nix/nix.conf"
export NIX_CONFIG='experimental-features = nix-command flakes'

generation=$(nix build --no-link --print-out-paths \
  "path:$repo#homeConfigurations.${profile}.activationPackage")
"$generation/activate"

systemctl --user daemon-reload
systemctl --user reset-failed dms.service 2>/dev/null || true
systemctl --user restart dms.service
REMOTE

echo "Deployment complete. Running health check..."
"$repo/scripts/healthcheck.sh" "$target"
