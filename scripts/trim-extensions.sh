#!/bin/sh
# Trim the VS Code Server bundled extension set down to what a tunnel session
# actually needs. This is what keeps the sandbox alive: the server's baseline is
# ~750 MB and the cgroup limit is 1 GiB, so a full extension set (36 bundled,
# copilot alone is 179 MB on disk) pushes it into OOM, which takes down bash and
# every other process in the container.
#
# Kept: tunnel-forwarding (the tunnel's own dependency), github-authentication,
# git + git-base (git declares extensionDependencies: [vscode.git-base]),
# simple-browser (lets you open the site inside VS Code so its localhost:8400
# reference resolves through the forwarded port), node_modules (shared runtime).
#
# Nothing is deleted: removed extensions are moved to $BACKUP and
# `restore` puts them back.
#
# Usage: trim-extensions.sh {status|trim|restore}

set -eu

BACKUP=${BACKUP:-/tmp/vsc-extensions-backup}
KEEP="git git-base github-authentication simple-browser tunnel-forwarding node_modules"

server_extensions_dir() {
  # Newest server dir wins if several builds are cached.
  d=$(ls -dt /tmp/.vscode/cli/servers/*/server/extensions 2>/dev/null | head -1)
  [ -n "$d" ] || { echo "no VS Code Server extensions dir found" >&2; exit 1; }
  printf '%s' "$d"
}

list_active() { ls "$(server_extensions_dir)" 2>/dev/null; }

count_active() { list_active | wc -l | tr -d ' '; }

is_kept() {
  for k in $KEEP; do [ "$1" = "$k" ] && return 0; done
  return 1
}

do_status() {
  d=$(server_extensions_dir)
  echo "extensions dir : $d"
  echo "active         : $(count_active)"
  printf '  %s\n' $KEEP
  echo "backed up      : $(ls "$BACKUP" 2>/dev/null | wc -l | tr -d ' ') in $BACKUP"
  echo "disk (active)  : $(du -sh "$d" 2>/dev/null | cut -f1)"
  echo
  echo "unexpected active entries (should be none):"
  for e in $(list_active); do is_kept "$e" || echo "  $e"; done
}

do_trim() {
  d=$(server_extensions_dir)
  mkdir -p "$BACKUP"
  moved=0
  for path in "$d"/*; do
    [ -e "$path" ] || continue
    e=$(basename "$path")
    if is_kept "$e"; then continue; fi
    mv "$path" "$BACKUP"/
    moved=$((moved+1))
  done
  echo "moved $moved extensions to $BACKUP"
  echo "active now: $(count_active) | disk: $(du -sh "$d" | cut -f1)"
  echo
  echo "Dependency check (each kept extension's extensionDependencies):"
  for e in $KEEP; do
    [ -f "$d/$e/package.json" ] || continue
    python3 - "$d/$e/package.json" "$e" <<'PY'
import json,sys
p,name=sys.argv[1],sys.argv[2]
d=json.load(open(p))
deps=d.get('extensionDependencies') or []
print(f"  {name}: {deps if deps else 'no deps'}")
PY
  done
}

do_restore() {
  d=$(server_extensions_dir)
  [ -d "$BACKUP" ] || { echo "nothing to restore from $BACKUP"; exit 1; }
  n=0
  for path in "$BACKUP"/*; do
    [ -e "$path" ] || continue
    mv "$path" "$d"/ && n=$((n+1))
  done
  echo "restored $n extensions; active now: $(count_active)"
}

case "${1:-status}" in
  status)  do_status ;;
  trim)    do_trim ;;
  restore) do_restore ;;
  *) echo "usage: $0 {status|trim|restore}"; exit 2 ;;
esac
