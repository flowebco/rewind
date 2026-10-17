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
# read and exec under /home/user but cannot reliably CREATE files there -- the
# workspace snapshot layer intermittently withdraws the directory, so a pidfile
# or log placed there silently never appears and the service runs blind. Worse,
# a watchdog whose exit condition depends on an unwritable pidfile loops forever.
# /tmp is plain and always works. The same quirk makes `sed -i` on files under
# /home/user unreliable, so prefer rewriting whole files there.
#
# Usage: tunnel-service.sh {start|stop|restart|status|log}

NAME=${TUNNEL_NAME:-vscode-arena}
CLI=${CLI:-/tmp/code}                     # see setup.sh: copied off /home/user
PIDFILE=/tmp/vscode-tunnel.pid
LOG=/tmp/vscode-tunnel.log

# Pin the CLI data dir so the tunnel reuses the cached GitHub auth and the
# trimmed extension set in /tmp/.vscode instead of re-downloading a fresh server.
VSCODE_CLI_DATA_DIR=/tmp/.vscode/cli
export VSCODE_CLI_DATA_DIR

# Cap node's heap so the VS Code Server extension host cannot balloon into the
# 1 GiB cgroup limit and OOM the whole sandbox (it did, repeatedly, at 16 procs).
NODE_OPTIONS=--max-old-space-size=192
export NODE_OPTIONS

SELF=$(readlink -f "$0" 2>/dev/null || echo "$0")

is_running() {
  [ -f "$PIDFILE" ] || return 1
  pid=$(cat "$PIDFILE" 2>/dev/null) || return 1
  [ -n "$pid" ] && [ -d "/proc/$pid" ]
}

run_loop() {
  echo $$ > "$PIDFILE"
  while [ -f "$PIDFILE" ]; do
    echo "=== tunnel start $(date -u '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"
    "$CLI" tunnel --accept-server-license-terms --name "$NAME" >> "$LOG" 2>&1
    echo "=== tunnel exited $(date -u '+%Y-%m-%d %H:%M:%S'), restart in 5s ===" >> "$LOG"
    sleep 5
  done
  echo "=== watchdog stopped $(date -u '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"
}

kill_tunnel_procs() {
  for p in /proc/[0-9]*; do
    pid=${p#/proc/}
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in
      */code\ tunnel\ --accept-server-license-terms*) kill -9 "$pid" 2>/dev/null ;;
    esac
  done
}

start() {
  if is_running; then
    echo "already running (watchdog pid $(cat "$PIDFILE"))"
    return 0
  fi
  [ -x "$CLI" ] || { echo "no CLI at $CLI -- run setup.sh first"; return 1; }
  : > "$LOG"                     # truncate, never unlink (avoids the sync race)
  setsid "$SELF" _loop > /dev/null 2>&1 < /dev/null &
  sleep 6
  if is_running; then
    echo "started (watchdog pid $(cat "$PIDFILE"))"
    echo "log: $LOG"
    echo "--- log ---"
    tr -d '\r' < "$LOG" | grep -v '^\*' | grep -v '^$' | head -8
    echo
    echo "If the log shows a 'github.com/login/device' code, the cached auth"
    echo "expired: open that URL, enter the code, then re-run: $0 status"
  else
    echo "FAILED to start; log follows:"
    tr -d '\r' < "$LOG" 2>/dev/null | tail -20
    return 1
  fi
}

stop() {
  if is_running; then
    pid=$(cat "$PIDFILE")
    rm -f "$PIDFILE"               # signals the loop to exit
    kill -9 "$pid" 2>/dev/null
    kill_tunnel_procs
    echo "stopped"
  else
    rm -f "$PIDFILE"
    kill_tunnel_procs
    echo "not running (stray tunnel procs cleaned)"
  fi
}

status() {
  if is_running; then
    echo "watchdog:          RUNNING (pid $(cat "$PIDFILE"))"
  else
    echo "watchdog:          STOPPED"
  fi

  n=0
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in */code\ tunnel\ --accept*) n=$((n+1));; esac
  done
  echo "tunnel procs:      $n"

  v=0; vrss=0
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in
      *.vscode/cli/servers*)
        v=$((v+1))
        s=$(awk '/VmRSS/{print $2}' "$p/status" 2>/dev/null)
        [ -n "$s" ] && vrss=$((vrss+s))
        ;;
    esac
  done
  echo "vscode-server:     $v procs, $((vrss/1024)) MB RSS"
  echo "extensions active: $(ls /tmp/.vscode/cli/servers/*/server/extensions 2>/dev/null | wc -l | tr -d ' ')"

  h=0
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in *live-server*) h=$((h+1));; esac
  done
  echo "impeccable helper: $h (port 8400)"

  px=0
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in *liveproxy*) px=$((px+1));; esac
  done
  echo "live proxy:        $px (port 8080)"

  cur=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null)
  lim=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
  cache=$(awk '/^cache/{print int($2/1048576)}' /sys/fs/cgroup/memory/memory.stat 2>/dev/null)
  [ -n "$cur" ] && [ -n "$lim" ] && \
    echo "cgroup mem:        $((cur/1048576)) / $((lim/1024/1024)) MB (${cache:-0} MB of that is reclaimable cache)"

  if [ -n "$VSCODE_CLI_DATA_DIR" ] && [ -x "$CLI" ]; then
    echo "--- tunnel registration ---"
    "$CLI" tunnel status 2>&1 | tr -d '\r' | head -2
  fi

  if [ -f "$LOG" ]; then
    echo "--- log tail ---"
    tr -d '\r' < "$LOG" | grep -v '^\*' | grep -v '^$' | tail -6
  fi
}

case "$1" in
  start)   start ;;
  stop)    stop ;;
  restart) stop; sleep 2; start ;;
  status)  status ;;
  log)     tr -d '\r' < "$LOG" | tail -40 ;;
  _loop)   run_loop ;;
  *) echo "usage: $0 {start|stop|restart|status|log}"; exit 2 ;;
esac
