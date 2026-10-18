#!/bin/sh
# Supervised VS Code tunnel "service" for containers without systemd/dbus.
#
# WHY NOT `code tunnel service install`: it drives systemd over a user dbus
# session. This container has neither -- PID 1 is the arena node server, there
# is no /run/systemd/system and no systemctl. It fails with:
#   error Error creating dbus session. This command uses systemd ...
# This watchdog supplies the same guarantees manually: detached, auto-restart on
# crash, logged, with a pidfile as the stop signal.
#
# WHY ALL STATE LIVES ON /tmp: detached (setsid) children in this sandbox can
# read and exec under the workspace path but cannot reliably CREATE files there,
# and `cd` into it fails intermittently. A watchdog whose exit condition depends
# on an unwritable pidfile loops forever, which happened once.
#
# Usage: tunnel-service.sh {start|stop|restart|status|log}

NAME=${TUNNEL_NAME:-qwen-agent}
CLI=${CLI:-/tmp/code}                     # restore.sh downloads it here
PIDFILE=/tmp/vscode-tunnel.pid
LOG=/tmp/vscode-tunnel.log

# DISABLE ALL EXTENSIONS. `code tunnel` has no --disable-all-extensions flag;
# pointing --extensions-dir at an empty directory is the equivalent, and it is
# stronger than deleting files from the default location because it also stops
# the connecting client from syncing extensions into it. Two of them have OOM'd
# this container before:
#   github.copilot-chat     crash-looped the extension host (6 hosts in 4 min)
#   ms-playwright.playwright ran two ~97 MB test-servers and scaffolded a Node
#                            project plus a GitHub Actions workflow into the repo
# EXT_DIR is recreated on every start because /tmp does not survive a restart.
EXT_DIR=${EXT_DIR:-/tmp/vsc-ext-empty}
DATA_DIR=${DATA_DIR:-/tmp/vsc-server-data}

# Pin the CLI data dir so the tunnel reuses the cached GitHub auth instead of
# demanding a fresh device code every time.
VSCODE_CLI_DATA_DIR=/tmp/.vscode/cli
export VSCODE_CLI_DATA_DIR

# Cap node's heap so the VS Code Server extension host cannot balloon into the
# 1 GiB cgroup limit and OOM the whole sandbox (it did, repeatedly, at 16 procs).
NODE_OPTIONS=--max-old-space-size=192
export NODE_OPTIONS

SELF=$(readlink -f "$0" 2>/dev/null || echo "$0")

# The service only allows [A-Za-z0-9-]. A space is rejected permanently, and a
# watchdog that retries a permanent error just burns attempts -- one run made 50
# useless tries while the user's authorize had already succeeded and nothing was
# registered. Validate before starting.
valid_name() {
  case "$NAME" in
    ''|*[!A-Za-z0-9-]*) return 1 ;;
  esac
  return 0
}

# Errors that will never succeed on retry, so halt instead of looping.
# Deliberately narrow: an earlier version matched the bare word 'license', which
# hit the VS Code Server License Terms banner that EVERY run prints, fired on a
# perfectly healthy start, and deleted the pidfile -- leaving a watchdog that
# could no longer be stopped with `stop`.
fatal_logged() {
  grep -qE 'error invalid name:|Names can only contain letters|\] error (unauthorized|forbidden|invalid)' "$LOG" 2>/dev/null
}

is_running() {
  [ -f "$PIDFILE" ] || return 1
  p=$(cat "$PIDFILE" 2>/dev/null) || return 1
  [ -n "$p" ] && [ -d "/proc/$p" ]
}

run_loop() {
  echo $$ > "$PIDFILE"
  mkdir -p "$EXT_DIR" "$DATA_DIR"
  [ -f "$EXT_DIR/extensions.json" ] || echo '[]' > "$EXT_DIR/extensions.json"
  while [ -f "$PIDFILE" ]; do
    echo "=== tunnel start $(date -u '+%Y-%m-%d %H:%M:%S') name=$NAME ===" >> "$LOG"
    "$CLI" tunnel --accept-server-license-terms --name "$NAME" \
      --extensions-dir "$EXT_DIR" --server-data-dir "$DATA_DIR" >> "$LOG" 2>&1
    echo "=== tunnel exited $(date -u '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"
    if fatal_logged; then
      {
        echo "=== FATAL: the log reports an error that retrying cannot fix."
        echo "=== Halting instead of looping. Fix the cause, delete $PIDFILE,"
        echo "=== then start again."
      } >> "$LOG"
      rm -f "$PIDFILE"
      break
    fi
    echo "=== restart in 5s ===" >> "$LOG"
    sleep 5
  done
}

start() {
  if ! valid_name; then
    echo "REFUSING TO START: '$NAME' is not a valid tunnel name." >&2
    echo "Only letters, numbers and '-' are allowed; the rejection is permanent." >&2
    echo "Try: TUNNEL_NAME=qwen-agent $SELF start" >&2
    exit 2
  fi
  if is_running; then
    echo "already running (watchdog pid $(cat "$PIDFILE"))"
    return 0
  fi
  [ -x "$CLI" ] || { echo "no CLI at $CLI -- run scripts/restore.sh first" >&2; return 1; }
  : > "$LOG"                     # truncate, never unlink (avoids the sync race)
  setsid "$SELF" _loop > /dev/null 2>&1 < /dev/null &
  sleep 8
  if fatal_logged; then
    echo "FAILED immediately with a permanent error:" >&2
    tr -d '\r' < "$LOG" | grep -iE 'invalid name|Names can only|\] error' | head -4 >&2
    rm -f "$PIDFILE"
    return 1
  fi
  if is_running; then
    echo "started (watchdog pid $(cat "$PIDFILE")), name=$NAME, extensions disabled"
    echo "log: $LOG"
    echo "--- log ---"
    tr -d '\r' < "$LOG" | grep -v '^\*' | grep -v '^$' | head -8
    echo
    echo "If the log shows a github.com/login/device code, give it to the USER:"
    echo "  tr -d '\\r' < $LOG | grep -o 'use code [A-Z0-9-]*' | tail -1"
    echo "Then VERIFY before claiming anything is ready:"
    echo "  VSCODE_CLI_DATA_DIR=/tmp/.vscode/cli $CLI tunnel status"
    echo "It must say \"tunnel\":\"Connected\". Until then the vscode.dev URL"
    echo "resolves to nothing and the user will report that the link is dead."
  else
    echo "FAILED to start; log follows:" >&2
    tr -d '\r' < "$LOG" 2>/dev/null | tail -20 >&2
    return 1
  fi
}

stop() {
  if is_running; then
    pid=$(cat "$PIDFILE")
    rm -f "$PIDFILE"                 # signals the loop to exit
    kill -9 "$pid" 2>/dev/null
  else
    rm -f "$PIDFILE"
  fi
  # Match on argv, never on the whole cmdline: a naive *code*tunnel* pattern also
  # matches the agent's own inspection command, and killing that mid-run once
  # looked like a competing tunnel and cost a valid GitHub token.
  for p in /proc/[0-9]*; do
    pid=${p#/proc/}
    a0=$(tr '\0' '\n' < "$p/cmdline" 2>/dev/null | head -1)
    a1=$(tr '\0' '\n' < "$p/cmdline" 2>/dev/null | sed -n 2p)
    case "$a0" in
      */code) [ "$a1" = "tunnel" ] && kill -9 "$pid" 2>/dev/null ;;
    esac
  done
  echo stopped
}

count_tunnels() {
  n=0
  for p in /proc/[0-9]*; do
    a0=$(tr '\0' '\n' < "$p/cmdline" 2>/dev/null | head -1)
    a1=$(tr '\0' '\n' < "$p/cmdline" 2>/dev/null | sed -n 2p)
    case "$a0" in */code) [ "$a1" = "tunnel" ] && n=$((n+1)) ;; esac
  done
  echo "$n"
}

status() {
  if is_running; then
    echo "watchdog:          RUNNING (pid $(cat "$PIDFILE"))"
  else
    echo "watchdog:          STOPPED"
  fi
  echo "name:              $NAME"
  echo "tunnel procs:      $(count_tunnels)   (must be 0 or 1; two registrations"
  echo "                                       for one name invalidate the token)"
  echo "extensions-dir:    $EXT_DIR -> $(ls "$EXT_DIR" 2>/dev/null | grep -vc extensions.json) extension(s)"

  v=0; vrss=0
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in
      *.vscode/cli/servers*|*.vscode-server*)
        v=$((v+1))
        s=$(awk '/VmRSS/{print $2}' "$p/status" 2>/dev/null)
        [ -n "$s" ] && vrss=$((vrss+s))
        ;;
    esac
  done
  echo "vscode-server:     $v procs, $((vrss/1024)) MB RSS"

  cur=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null)
  lim=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
  cache=$(awk '/^cache/{print int($2/1048576)}' /sys/fs/cgroup/memory/memory.stat 2>/dev/null)
  [ -n "$cur" ] && [ -n "$lim" ] && \
    echo "cgroup mem:        $((cur/1048576)) / $((lim/1048576)) MB (${cache:-0} MB reclaimable)"

  if [ -x "$CLI" ]; then
    echo "--- registration ---"
    "$CLI" tunnel status 2>&1 | tr -d '\r' | head -2
  fi
  if [ -f "$LOG" ]; then
    echo "--- log tail ---"
    tr -d '\r' < "$LOG" | grep -v '^\*' | grep -v '^$' | tail -6
  fi
}

case "${1:-start}" in
  start)   start ;;
  stop)    stop ;;
  restart) stop; sleep 2; start ;;
  status)  status ;;
  log)     tr -d '\r' < "$LOG" | tail -40 ;;
  _loop)   run_loop ;;
  *) echo "usage: $0 {start|stop|restart|status|log}"; exit 2 ;;
esac
