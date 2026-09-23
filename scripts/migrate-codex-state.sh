#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/migrate-codex-state.sh user@host

Run this from the source machine after Codex has been fully closed on both
machines. The target's existing Codex directory is backed up before migration.
Authentication and the target installation ID remain target-local.
EOF
}

if [[ $# -ne 1 || ${1:-} == -h || ${1:-} == --help ]]; then
  usage
  [[ ${1:-} == -h || ${1:-} == --help ]] && exit 0
  exit 2
fi

target=$1
source_dir=${CODEX_HOME:-$HOME/.codex}
identity_file=${NIRI_MIGRATION_IDENTITY:-$HOME/.ssh/id_ed25519_niri_migration}
identity_args=()
[[ -f $identity_file ]] && identity_args=(-i "$identity_file")

codex_is_running_local() {
  pgrep -u "$USER" -x codex >/dev/null 2>&1 ||
    pgrep -u "$USER" -x codex-code-mode-host >/dev/null 2>&1 ||
    pgrep -u "$USER" -f '[n]ode .*/codex([[:space:]]|$)' >/dev/null 2>&1
}

if codex_is_running_local; then
  echo "Codex is still running on the source machine." >&2
  echo "Close every Codex CLI/Desktop session, then run this script again from a normal terminal." >&2
  exit 1
fi

[[ -d $source_dir ]] || {
  echo "Source Codex directory does not exist: $source_dir" >&2
  exit 1
}

remote_home=$(ssh "${identity_args[@]}" "$target" 'printf %s "$HOME"')
remote_dir=$remote_home/.codex
timestamp=$(date +%Y%m%d-%H%M%S)
remote_backup=$remote_home/.codex-before-migration-$timestamp

if ssh "${identity_args[@]}" "$target" \
  'pgrep -u "$USER" -x codex >/dev/null 2>&1 ||
   pgrep -u "$USER" -x codex-code-mode-host >/dev/null 2>&1 ||
   pgrep -u "$USER" -f '\''[n]ode .*/codex([[:space:]]|$)'\'' >/dev/null 2>&1'; then
  echo "Codex is still running on the target machine." >&2
  echo "Close every Codex CLI/Desktop session there, then run this script again." >&2
  exit 1
fi

source_bytes=$(du -sb "$source_dir" | awk '{print $1}')
target_free=$(ssh "${identity_args[@]}" "$target" "df -PB1 '$remote_home' | awk 'NR==2 {print \$4}'")
if (( target_free < source_bytes * 2 )); then
  echo "Target may not have enough free space for the migration and safety backup." >&2
  echo "Required: approximately $((source_bytes * 2 / 1024 / 1024 / 1024 + 1)) GiB; available: $((target_free / 1024 / 1024 / 1024)) GiB." >&2
  exit 1
fi

echo "Backing up target Codex state to $remote_backup"
ssh "${identity_args[@]}" "$target" \
  "if [[ -d '$remote_dir' ]]; then mv '$remote_dir' '$remote_backup'; fi; mkdir -p '$remote_dir'"

echo "Copying Codex conversations and state..."
rsync -a --partial --info=progress2 \
  --exclude='/auth*.json' \
  --exclude='/installation_id' \
  --exclude='/.tmp/' \
  --exclude='/tmp/' \
  --exclude='/ipc/' \
  --exclude='/app-server-control/' \
  --exclude='/app-server-daemon/' \
  --exclude='/thread-writer-locks/' \
  --exclude='/mcp-oauth-locks/' \
  --exclude='/process_manager/' \
  --exclude='/shell_snapshots/' \
  --exclude='/node_repl/' \
  --exclude='/cache/' \
  --exclude='/log/' \
  --exclude='/version.json' \
  -e "ssh ${identity_args[*]}" \
  "$source_dir/" "$target:$remote_dir/"

echo "Restoring target-local credentials and merging target sessions..."
ssh "${identity_args[@]}" "$target" bash --noprofile --norc -s -- \
  "$remote_dir" "$remote_backup" <<'REMOTE'
set -euo pipefail
codex_dir=$1
backup_dir=$2

shopt -s nullglob
for file in "$backup_dir"/auth*.json "$backup_dir"/installation_id; do
  cp -a "$file" "$codex_dir/"
done

for tree in sessions archived_sessions attachments; do
  if [[ -d $backup_dir/$tree ]]; then
    mkdir -p "$codex_dir/$tree"
    rsync -a --ignore-existing "$backup_dir/$tree/" "$codex_dir/$tree/"
  fi
done

find "$codex_dir" -type d -exec chmod u+rwx {} +
find "$codex_dir" -type f -exec chmod u+rw {} +

if command -v codex >/dev/null 2>&1; then
  codex migrate-rollouts --apply
fi
REMOTE

echo
echo "Codex migration completed. Target backup: $remote_backup"
echo "On the target, verify with: codex resume --all"
