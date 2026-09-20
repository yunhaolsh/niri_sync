#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/healthcheck.sh user@host" >&2
  exit 2
fi

target=$1
identity_file=${NIRI_MIGRATION_IDENTITY:-$HOME/.ssh/id_ed25519_niri_migration}
identity_args=()
[[ -f "$identity_file" ]] && identity_args=(-i "$identity_file")

ssh "${identity_args[@]}" -o BatchMode=yes "$target" 'bash --noprofile --norc -s' <<'REMOTE'
set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.nix-profile/bin:$PATH"

. /etc/os-release
printf 'OS: %s\n' "$PRETTY_NAME"

failed=0
for command in niri ghostty fcitx5 dms dsearch nirius niriusd; do
  if path=$(command -v "$command" 2>/dev/null); then
    printf '%-12s OK %s\n' "$command" "$path"
  else
    printf '%-12s MISSING\n' "$command"
    failed=1
  fi
done

if niri validate >/dev/null 2>&1; then
  echo 'niri-config OK'
else
  echo 'niri-config INVALID'
  failed=1
fi

printf 'dms-service  %s\n' "$(systemctl --user is-active dms.service 2>/dev/null || true)"
printf 'waybar       %s\n' "$(systemctl --user is-enabled waybar.service 2>/dev/null || true)"

pid=$(systemctl --user show dms.service -p MainPID --value 2>/dev/null || true)
if [[ -n $pid && $pid != 0 ]]; then
  errors=$(journalctl --user _PID="$pid" --no-pager -o cat 2>/dev/null |
    grep -Ec 'EGL not available|Failed to create (RHI|QRhi|graphics context)|scenegraph is not functional' || true)
  printf 'dms-graphics  %s error(s)\n' "$errors"
  [[ $errors == 0 ]] || failed=1
fi

exit "$failed"
REMOTE
