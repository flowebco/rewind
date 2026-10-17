#!/bin/sh
# ============================================================================
# restore.sh -- bring a FRESH sandbox from "just cloned" to "live mode running"
# ============================================================================
#
# Run from the repo root:       sh scripts/restore.sh
# Report only, change nothing:  sh scripts/restore.sh --status
#
# This script exists because the environment is ephemeral and hostile in ways
# that are NOT discoverable from the code. Every workaround below was paid for
# with a real failure; the reason is documented inline so nobody re-learns it.
#
#   1. report the memory budget      (the hard limit that shapes everything)
#   2. install the VS Code CLI       (no curl/wget -> Python)
#   3. install the impeccable engine (only a Windows binary ships in-repo)
#   4. write the live-mode config
#   5. trim VS Code Server extensions (MANDATORY on 1 GiB, not optional)
#   6. start the same-origin proxy   (without it live mode cannot work at all)
#   7. boot impeccable live
#   8. print tunnel instructions     (needs a human, so not automated)

set -u

# ---------------------------------------------------------------------------
# PATH RESOLUTION -- read this before "fixing" it
# ---------------------------------------------------------------------------
# REPO is the caller's cwd, NOT a hardcoded path and NOT `dirname $0`.
#
# In this sandbox the agent's persistent workspace ("$ARENA_WORKSPACE") is a separate
# mount that does not appear in `ls /home` and that spawned processes cannot
# reliably write to, even though they can read and exec through it. Observed:
#     cd "$ARENA_WORKSPACE"/...        -> ENOENT, intermittently
#     creating a file there    -> "Directory nonexistent"
#     sed -i on a file there   -> exits 0, file unchanged
#     dirname "$0"             -> resolves, but the dir is not always openable
# The interactive shell's cwd DOES resolve, so inherit it and verify.
REPO=${REPO:-$PWD}
[ -f "$REPO/blogs.html" ] && [ -d "$REPO/.git" ] || {
  echo "restore.sh: '$REPO' is not the repo root." >&2
  echo "usage: cd <repo> && sh scripts/restore.sh" >&2
  exit 2
}
S=$REPO/scripts

# ALL mutable service state goes on /tmp. See above for why.
CLI=/tmp/code
PIDFILE=/tmp/vscode-tunnel.pid
TUNNEL_LOG=/tmp/vscode-tunnel.log
PROXY_LOG=/tmp/liveproxy.log
EXT_BACKUP=/tmp/vsc-extensions-backup
SITE_PORT=8080
HELPER_PORT=8400

say()  { printf '\n=== %s\n' "$1"; }
ok()   { printf '   ok    %s\n' "$1"; }
note() { printf '   ..    %s\n' "$1"; }
warn() { printf '   WARN  %s\n' "$1"; }
bad()  { printf '   FAIL  %s\n' "$1"; }

mem_report() {
  say "1. Memory budget"
  lim=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo 0)
  cur=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || echo 0)
  cache=$(awk '/^cache/{print int($2/1048576)}' /sys/fs/cgroup/memory/memory.stat 2>/dev/null || echo 0)
  [ "$lim" = 0 ] && { warn "could not read the cgroup limit"; return 0; }
  echo "   limit $((lim/1048576)) MB | in use $((cur/1048576)) MB | ${cache} MB of that is reclaimable cache"
  echo "   real headroom ~$(( (lim-cur)/1048576 + cache )) MB"
  if [ "$lim" -le 1073741824 ]; then
    warn "1 GiB or less. A connected VS Code Server costs ~700-750 MB even"
    warn "trimmed to 6 extensions. With the full 36 it reaches 816 MB / 16"
    warn "processes and OOM-kills the container, taking bash and every agent"
    warn "tool down with it. Step 5 is therefore mandatory, not optional."
  fi
}

install_cli() {
  say "2. VS Code CLI"
  if [ -x "$CLI" ]; then ok "$CLI ($("$CLI" --version 2>/dev/null | head -1))"; return 0; fi
  note "downloading the alpine-x64 build (musl-static, needs no libs)"
  python3 - "$CLI" <<'PY' || { bad "CLI download failed"; return 1; }
import os, sys, tarfile, tempfile, urllib.request
dst = sys.argv[1]
url = 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64'
r = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(r, timeout=180) as resp:
    data = resp.read()
print(f'   ..    fetched {len(data)} bytes')
d = tempfile.mkdtemp(); tgz = os.path.join(d, 'cli.tar.gz')
open(tgz, 'wb').write(data)
try:
    with tarfile.open(tgz) as t:
        t.extractall(d)
    found = os.path.join(d, 'code')
    if not os.path.exists(found):
        for root, _, files in os.walk(d):
            if 'code' in files:
                found = os.path.join(root, 'code'); break
    os.replace(found, dst); os.chmod(dst, 0o755)
    print(f'   ok    unpacked -> {dst}')
except tarfile.ReadError:
    open(dst, 'wb').write(data); os.chmod(dst, 0o755)
    print(f'   ok    wrote the bare binary -> {dst}')
PY
  "$CLI" --version 2>&1 | sed 's/^/   /'
}

install_engine() {
  say "3. Impeccable engine"
  ver=$(cat "$REPO/.agents/skills/impeccable/scripts/VERSION" 2>/dev/null || echo 0.1.15)
  eng=$REPO/.impeccable-engine/bin/$ver/impeccable
  if [ -x "$eng" ]; then ok "already installed ($ver)"; return 0; fi
  # The launcher's own downloader shells out to curl/wget, neither of which
  # exists here, so it fails with "check network access ... and curl or wget
  # availability". Only scripts/bin/windows-x64 ships in-repo. Fetch linux-x64
  # ourselves and verify the published .sha256 sidecar exactly as the launcher
  # would: refuse to exec an unverified download.
  note "downloading engine $ver (linux-x64) with sha256 verification"
  mkdir -p "$(dirname "$eng")"
  python3 - "$ver" "$eng" <<'PY' || { bad "engine install failed"; return 1; }
import hashlib, os, sys, urllib.request
ver, dst = sys.argv[1], sys.argv[2]
base = os.environ.get('IMPECCABLE_DOWNLOAD_BASE',
                      'https://github.com/pbakaus/impeccable/releases/download')
url = f'{base}/engine-v{ver}/impeccable-linux-x64'
def get(u):
    r = urllib.request.Request(u, headers={'User-Agent': 'impeccable-restore'})
    with urllib.request.urlopen(r, timeout=180) as resp:
        return resp.read()
try:
    expected = get(url + '.sha256').decode().split()[0]
except Exception as e:
    print('   FAIL could not fetch the sha256 sidecar:', e); sys.exit(1)
data = get(url)
actual = hashlib.sha256(data).hexdigest()
if actual != expected:
    print(f'   FAIL checksum mismatch\n     expected {expected}\n     actual   {actual}')
    print('   refusing to install an unverified binary'); sys.exit(1)
open(dst, 'wb').write(data); os.chmod(dst, 0o755)
print(f'   ok    {len(data)} bytes, sha256 {actual[:16]}... verified')
PY
  lau=$REPO/.agents/skills/impeccable/scripts/impeccable
  [ -x "$lau" ] || { chmod +x "$lau" && ok "chmod +x on the launcher (ships non-executable)"; }
}

write_config() {
  say "4. Live-mode config"
  cfg=$REPO/.impeccable/live/config.json
  if [ -f "$cfg" ]; then ok "already present"; sed 's/^/         /' "$cfg"; return 0; fi
  mkdir -p "$REPO/.impeccable/live"
  cat > "$cfg" <<'JSON'
{
  "files": ["*.html"],
  "exclude": [".impeccable/**", ".agents/**", ".playwright-mcp/**"],
  "insertBefore": "</body>",
  "commentSyntax": "html",
  "cspChecked": true
}
JSON
  ok "wrote $cfg"
  note "cspChecked is true because detect-csp reports shape null here (no CSP"
  note "meta tag, no middleware). Re-run detect-csp if that ever changes."
}

trim_ext() {
  say "5. VS Code Server extensions"
  if [ -f "$S/trim-extensions.sh" ]; then sh "$S/trim-extensions.sh" trim
  else bad "trim-extensions.sh missing -- do NOT start the tunnel on a 1 GiB box"; fi
}

start_proxy() {
  say "6. Same-origin live proxy on :$SITE_PORT"
  # Mandatory, not a convenience: live.js hardcodes 'http://localhost:' + PORT
  # for ~14 endpoints. On an HTTPS devtunnels origin that fails twice -- mixed
  # content, and localhost is the viewer's own machine. Forwarding the helper
  # port cannot help: the URL is not derived from the page origin. Cross-origin
  # is also out, because the helper sends Access-Control-Allow-Methods and
  # Allow-Headers but NO Access-Control-Allow-Origin. So one origin serves both
  # the pages and the helper endpoints, rewriting live.js in flight.
  owner=""
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in *liveproxy.py*) owner=${p#/proc/} ;; esac
  done
  if [ -n "$owner" ]; then
    note "already running (pid $owner); a second one would only fail to bind"
  else
    for p in /proc/[0-9]*; do
      c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
      case "$c" in *http.server*$SITE_PORT*) kill -9 "${p#/proc/}" 2>/dev/null; note "stopped a plain http.server squatting on :$SITE_PORT" ;; esac
    done
    sleep 1
    [ -f "$S/liveproxy.py" ] || { bad "scripts/liveproxy.py missing"; return 1; }
    setsid nohup python3 "$S/liveproxy.py" "$REPO" "$SITE_PORT" > "$PROXY_LOG" 2>&1 < /dev/null &
    sleep 5
  fi
  # Verify by asking for the page. Never trust the pid alone.
  if python3 -c "
import sys, urllib.request
sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:$SITE_PORT/blogs.html', timeout=6).status == 200 else 1)
" 2>/dev/null; then
    ok "serving $REPO on :$SITE_PORT"
    note "it rewrites the injected <script src> to same-origin /live.js and"
    note "patches live.js's hardcoded localhost URLs (22 -> 1; the survivor is"
    note "inside a comment). Files on disk are never touched, so live-inject"
    note "keeps working normally."
    note "BUG AVOIDED: keep template literals as backticks when rewriting, or"
    note "\`/design-system.json?token=\${TOKEN}\` stops interpolating."
  else
    bad "proxy is not answering on :$SITE_PORT -- see $PROXY_LOG"
  fi
}

boot_live() {
  say "7. Impeccable live"
  eng=$REPO/.impeccable-engine
  [ -d "$eng" ] || { bad "engine missing; step 3 must have failed"; return 1; }
  # TRAP: a stale .impeccable/live/server.json makes `impeccable live` report
  # ok:true while NO helper is running -- it trusts the file and never checks
  # the pid. Port 8400 then stays closed and the proxy returns 502. If the
  # recorded pid is dead, delete the file so a real helper gets spawned.
  sj=$REPO/.impeccable/live/server.json
  if [ -f "$sj" ]; then
    stale=$(python3 -c "
import json, os, sys
try: pid = str(json.load(open('$sj'))['pid'])
except Exception: print('yes'); sys.exit(0)
print('no' if os.path.isdir('/proc/' + pid) else 'yes')
" 2>/dev/null)
    [ "$stale" = "yes" ] && { rm -f "$sj"; warn "removed a stale server.json (its pid was dead); forcing a fresh helper"; }
  fi
  ( cd "$REPO" && IMPECCABLE_HOME=$eng \
      "$REPO/.agents/skills/impeccable/scripts/impeccable" live ) 2>&1 | python3 -c "
import sys, json
raw = sys.stdin.read()
try: d = json.loads(raw)
except Exception:
    print(raw[:500]); sys.exit(0)
if not d.get('ok'):
    print('   FAIL', {k: d.get(k) for k in ('error','path')}); sys.exit(1)
print('   ok    helper on port %s, projectRoot %s' % (d.get('serverPort'), d.get('projectRoot')))
print('         pageFiles %s' % d.get('pageFiles'))
print('         product/design/surfaceBrief %s/%s/%s  configDrift %s' % (
    d.get('hasProduct'), d.get('hasDesign'), d.get('hasSurfaceBrief'), d.get('configDrift')))
"
  # `impeccable live` sometimes leaves an extra idle helper. Only the pid in
  # server.json owns the port; kill the rest.
  auth=$(python3 -c "import json;print(json.load(open('$sj'))['pid'])" 2>/dev/null)
  if [ -n "${auth:-}" ]; then
    for p in /proc/[0-9]*; do
      q=${p#/proc/}
      c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
      case "$c" in
        *live-server*) [ "$q" != "$auth" ] && kill -9 "$q" 2>/dev/null && note "killed a stray idle helper $q (authoritative is $auth)" ;;
      esac
    done
    ok "helper pid $auth owns :$HELPER_PORT"
  fi
}

tunnel_howto() {
  say "8. Tunnel -- needs a human, so it is NOT automated"
  cat <<EOF
   a) \`code tunnel service install\` CANNOT work here: it drives systemd over a
      user dbus session and this container has neither (PID 1 is a node server,
      no /run/systemd/system, no systemctl). It fails with "Error creating dbus
      session". scripts/tunnel-service.sh substitutes a watchdog: detached,
      auto-restart, logged, pidfile as the stop signal.

   b) EXACTLY ONE tunnel may run. Two competing registrations for the same name
      invalidate the GitHub token server-side, after which every retry demands a
      new device code forever. Beware: a naive *code*tunnel* process match also
      catches the agent's OWN inspection command. Match on argv instead:
      argv[0] ends with /code AND argv[1] == tunnel.

   Start it from the repo root:
       CLI=$CLI sh $S/tunnel-service.sh start

   Read the device code and give it to the USER:
       tr -d '\\r' < $TUNNEL_LOG | grep -o 'use code [A-Z0-9-]*' | tail -1
   They open https://github.com/login/device and enter it. Codes last ~15 min.

   VERIFY before claiming anything is ready -- never trust the log alone:
       VSCODE_CLI_DATA_DIR=/tmp/.vscode/cli $CLI tunnel status
   It must show "tunnel":"Connected" with non-null name and tunnel_id. Until
   then the vscode.dev URL resolves to nothing and the user will report that
   the link does not connect.

   The cached auth in /tmp/.vscode/cli does NOT survive container restarts or
   repeated crashes, so expect to need a fresh device code.
EOF
}

report() {
  mem_report
  say "Current state"
  printf '   repo           %s\n' "$REPO"
  printf '   HEAD           %s\n' "$(git -C "$REPO" log --oneline -1 2>/dev/null)"
  printf '   vs origin      %s\n' "$(git -C "$REPO" status -sb 2>/dev/null | head -1)"
  printf '   CLI            %s\n' "$([ -x "$CLI" ] && echo "present at $CLI" || echo MISSING)"
  ver=$(cat "$REPO/.agents/skills/impeccable/scripts/VERSION" 2>/dev/null || echo 0.1.15)
  printf '   engine         %s\n' "$([ -x "$REPO/.impeccable-engine/bin/$ver/impeccable" ] && echo "present ($ver)" || echo MISSING)"
  printf '   extensions     %s active, %s backed up in %s\n' \
    "$(ls /tmp/.vscode/cli/servers/*/server/extensions 2>/dev/null | wc -l | tr -d ' ')" \
    "$(ls "$EXT_BACKUP" 2>/dev/null | wc -l | tr -d ' ')" "$EXT_BACKUP"
  for pat in liveproxy.py live-server; do
    n=0
    for p in /proc/[0-9]*; do
      c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
      case "$c" in *$pat*) n=$((n+1));; esac
    done
    printf '   %-14s %s process(es)\n' "$pat" "$n"
  done
  n=0
  for p in /proc/[0-9]*; do
    a0=$(tr '\0' '\n' < "$p/cmdline" 2>/dev/null | head -1)
    a1=$(tr '\0' '\n' < "$p/cmdline" 2>/dev/null | sed -n 2p)
    case "$a0" in */code) [ "$a1" = "tunnel" ] && n=$((n+1)) ;; esac
  done
  printf '   %-14s %s process(es)\n' "tunnel" "$n"
  if [ -x "$CLI" ]; then
    echo "   tunnel registration:"
    VSCODE_CLI_DATA_DIR=/tmp/.vscode/cli "$CLI" tunnel status 2>&1 | tr -d '\r' | head -2 | sed 's/^/     /'
  fi
}

if [ "${1:-}" = "--status" ]; then report; exit 0; fi

mem_report
install_cli
install_engine
write_config
trim_ext
start_proxy
boot_live
tunnel_howto

say "Done"
cat <<EOF
   Remaining manual steps:
     1. CLI=$CLI sh $S/tunnel-service.sh start
     2. give the user the device code from $TUNNEL_LOG
     3. confirm "tunnel":"Connected" via \`tunnel status\`
     4. user forwards port $SITE_PORT only -- NOT $HELPER_PORT, the proxy serves
        every helper endpoint from the same origin
     5. user opens http://localhost:$SITE_PORT/blogs.html in Simple Browser
     6. only then start the poll loop:
          IMPECCABLE_HOME=$REPO/.impeccable-engine \\
            $REPO/.agents/skills/impeccable/scripts/impeccable live-poll

   After each ACCEPT, carbonize cleanup is mandatory before polling again.
   Commit with:  sh $S/auto-commit.sh "message"
   It excludes the dev-only live-inject tag by staging de-scaffolded content
   into the index, so the working files are never mutated.

   Read AGENTS.md before editing anything: design constraints, measured contrast
   ratios, and the user's standing preferences are all in there.
EOF
