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
# THERE ARE TWO EXTENSION DIRECTORIES and you must trim BOTH:
#
#   /tmp/.vscode/cli/servers/*/server/extensions   bundled, ships with the server
#   /tmp/.vscode-server/extensions                 user/gallery installs
#
# The second one is the dangerous one. VS Code silently auto-installs
# github.copilot-chat there (~76 MB) when the connecting client has a chat
# session open. It then activates on every extension host start
# (activationEvent 'onChatSession:claude-code'), fails to authenticate
# (GitHubLoginFailed, because the remote session has no Copilot login), fails to
# find @vscode/ripgrep (genuinely absent from the server tree), and the host dies
# with "FATAL ERROR: ... JavaScript heap out of memory" -> SIGABRT. VS Code
# restarts it, and it loops every ~25 seconds, each cycle spawning fresh
# processes, until the 1 GiB cgroup is exhausted and the tunnel itself aborts on
# a 20 KB allocation. Observed live: extension hosts 17300, 20919, 20941, 20960,
# 21033, 21108 in four minutes.
#
# Usage: trim-extensions.sh {status|trim|trim-user|restore}

set -eu

BACKUP=${BACKUP:-/tmp/vsc-extensions-backup}
USER_BACKUP=${USER_BACKUP:-/tmp/vscode-user-extensions-backup}
USER_EXT_DIR=/tmp/.vscode-server/extensions
KEEP="git git-base github-authentication simple-browser tunnel-forwarding node_modules"
# Nothing in the gallery directory is worth keeping in this sandbox: the user
# edits over a tunnel and does not need Copilot Chat, and Copilot Chat here is
# actively fatal (see the header). Override USER_KEEP to keep something.
USER_KEEP=${USER_KEEP:-}

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
  echo "user/gallery dir: $USER_EXT_DIR"
  if [ -d "$USER_EXT_DIR" ]; then
    echo "  installed    : $(ls "$USER_EXT_DIR" 2>/dev/null | grep -v '^extensions.json$' | wc -l | tr -d ' ')"
    echo "  on disk      : $(du -sh "$USER_EXT_DIR" 2>/dev/null | cut -f1)"
    echo "  backed up    : $(ls "$USER_BACKUP" 2>/dev/null | wc -l | tr -d ' ') in $USER_BACKUP"
    ls "$USER_EXT_DIR" 2>/dev/null | grep -v '^extensions.json$' | sed 's/^/    - /'
  else
    echo "  (absent)"
  fi
  echo
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

# Disable gallery-installed extensions by moving them out AND emptying the
# manifest, because VS Code reads extensions.json to decide what to activate.
# Moving the directory alone leaves a manifest entry pointing at nothing.
do_trim_user() {
  if [ ! -d "$USER_EXT_DIR" ]; then
    echo "no $USER_EXT_DIR -- nothing gallery-installed"
    return 0
  fi
  mkdir -p "$USER_BACKUP"
  n=0
  for path in "$USER_EXT_DIR"/*; do
    [ -e "$path" ] || continue
    e=$(basename "$path")
    [ "$e" = "extensions.json" ] && continue
    keep=0
    for k in $USER_KEEP; do [ "$e" = "$k" ] && keep=1; done
    [ "$keep" = 1 ] && continue
    mv "$path" "$USER_BACKUP"/ && n=$((n+1))
  done
  # Back up the manifest once, then empty it.
  if [ -f "$USER_EXT_DIR/extensions.json" ] && [ ! -f "$USER_BACKUP/extensions.json.orig" ]; then
    cp "$USER_EXT_DIR/extensions.json" "$USER_BACKUP/extensions.json.orig"
  fi
  echo '[]' > "$USER_EXT_DIR/extensions.json"
  echo "moved $n gallery extension(s) to $USER_BACKUP; extensions.json emptied"
  echo "VS Code logs 'Extensions removed from another source' and rebuilds the host."
  echo "The client may re-install Copilot Chat on its next connect -- re-run this if"
  echo "the extension host starts crash-looping again."
}

do_trim() {
  do_trim_user
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
  echo "restored $n bundled extensions; active now: $(count_active)"
  if [ -d "$USER_BACKUP" ]; then
    mkdir -p "$USER_EXT_DIR"
    m=0
    for path in "$USER_BACKUP"/*; do
      [ -e "$path" ] || continue
      b=$(basename "$path")
      [ "$b" = "extensions.json.orig" ] && continue
      mv "$path" "$USER_EXT_DIR"/ && m=$((m+1))
    done
    if [ -f "$USER_BACKUP/extensions.json.orig" ]; then
      cp "$USER_BACKUP/extensions.json.orig" "$USER_EXT_DIR/extensions.json"
      echo "restored $m gallery extension(s) and the original manifest"
    else
      echo "restored $m gallery extension(s); rebuild the manifest by reinstalling"
    fi
  fi
}

case "${1:-status}" in
  status)    do_status ;;
  trim)      do_trim ;;
  trim-user) do_trim_user ;;
  restore)   do_restore ;;
  *) echo "usage: $0 {status|trim|trim-user|restore}"; exit 2 ;;
esac
