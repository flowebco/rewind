#!/bin/sh
# Bring a fresh sandbox up to a working impeccable-live session.
#
# Idempotent: safe to re-run. Every step checks whether it is already done.
# Run from anywhere; it resolves the repo from its own location.
#
#   scripts/setup.sh            # full setup
#   scripts/setup.sh --status   # just report, change nothing
#
# Order matters. Extensions are trimmed BEFORE the tunnel is started, because a
# first connection with the full 36-extension set grows VS Code Server past the
# 1 GiB cgroup limit and OOM-kills the container (including bash itself).

set -u

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO=$(dirname "$HERE")
SCRIPTS=$HERE

# Spawned processes in this sandbox intermittently cannot resolve an absolute
# workspace path. Fail loudly rather than writing to the wrong place.
[ -d "$REPO/.git" ] || {
  echo "setup.sh: resolved repo as '$REPO' but there is no .git there." >&2
  echo "Run it from the repo root: sh scripts/setup.sh" >&2
  exit 2
}

CLI_SRC=$REPO/code                        # present only if someone copied it here
CLI=/tmp/code
ENGINE_VERSION=$(cat "$REPO/.agents/skills/impeccable/scripts/VERSION" 2>/dev/null || echo 0.1.15)
ENGINE_HOME=$REPO/.impeccable-engine
LAUNCHER=$REPO/.agents/skills/impeccable/scripts/impeccable
CONFIG=$REPO/.impeccable/live/config.json
SITE_PORT=8080
HELPER_PORT=8400

say() { printf '\n== %s\n' "$1"; }
ok()  { printf '   ok   %s\n' "$1"; }
warn(){ printf '   WARN %s\n' "$1"; }
bad() { printf '   FAIL %s\n' "$1"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- memory budget
check_memory() {
  say "Memory budget"
  lim=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo 0)
  cur=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || echo 0)
  if [ "$lim" -gt 0 ]; then
    echo "   cgroup limit $((lim/1048576)) MB, in use $((cur/1048576)) MB"
    if [ "$lim" -le 1073741824 ]; then
      warn "1 GiB or less: extension trimming is mandatory, not optional."
    fi
  else
    warn "could not read the cgroup memory limit"
  fi
}

# ------------------------------------------------------------------- engine bin
fetch_engine() {
  say "Impeccable engine $ENGINE_VERSION"
  bin=$ENGINE_HOME/bin/$ENGINE_VERSION/impeccable
  if [ -x "$bin" ]; then ok "already at $bin"; return 0; fi

  base=${IMPECCABLE_DOWNLOAD_BASE:-https://github.com/pbakaus/impeccable/releases/download}
  url=$base/engine-v$ENGINE_VERSION/impeccable-linux-x64
  mkdir -p "$(dirname "$bin")"

  # The launcher's own downloader shells out to curl or wget. Neither exists in
  # this image, so it fails with "check network access ... and curl or wget
  # availability". Fetch with Python instead and verify the sha256 sidecar the
  # same way the launcher would: refuse to run an unverified binary.
  python3 - "$url" "$bin" <<'PY'
import hashlib, os, sys, urllib.request
url, dst = sys.argv[1], sys.argv[2]
def get(u):
    r = urllib.request.Request(u, headers={'User-Agent': 'impeccable-setup'})
    with urllib.request.urlopen(r, timeout=120) as resp:
        return resp.read()
try:
    side = get(url + '.sha256').decode().split()[0]
except Exception as e:
    print('   FAIL could not fetch sha256 sidecar:', e); sys.exit(1)
data = get(url)
actual = hashlib.sha256(data).hexdigest()
if actual != side:
    print(f'   FAIL checksum mismatch\n     expected {side}\n     actual   {actual}')
    sys.exit(1)
open(dst, 'wb').write(data)
os.chmod(dst, 0o755)
print(f'   ok   downloaded {len(data)} bytes, sha256 verified')
PY
  [ $? -eq 0 ] || { bad "engine download failed"; return 1; }
}

# ------------------------------------------------------------- launcher + config
prep_launcher() {
  say "Launcher and live config"
  if [ -f "$LAUNCHER" ] && [ ! -x "$LAUNCHER" ]; then
    chmod +x "$LAUNCHER" && ok "chmod +x on the launcher (ships non-executable)"
  else
    ok "launcher executable"
  fi

  if [ -f "$CONFIG" ]; then
    ok "config present: $(tr -d '\n ' < "$CONFIG" | cut -c1-90)"
    return 0
  fi
  mkdir -p "$(dirname "$CONFIG")"
  cat > "$CONFIG" <<'JSON'
{
  "files": ["*.html"],
  "exclude": [".impeccable/**", ".agents/**", ".playwright-mcp/**"],
  "insertBefore": "</body>",
  "commentSyntax": "html",
  "cspChecked": true
}
JSON
  ok "wrote $CONFIG"
  echo "        cspChecked is true because detect-csp reports shape null for this"
  echo "        repo (no CSP meta tag, no middleware). Re-run detect-csp if that changes."
}

# --------------------------------------------------------------------- trim ext
trim_extensions() {
  say "Extension set"
  if [ -f "$SCRIPTS/trim-extensions.sh" ]; then
    sh "$SCRIPTS/trim-extensions.sh" trim
  else
    warn "trim-extensions.sh missing; skipping (dangerous on a 1 GiB box)"
  fi
}

# ---------------------------------------------------------------------- the CLI
place_cli() {
  say "VS Code CLI"
  if [ -x "$CLI" ]; then ok "already at $CLI"; return 0; fi
  src=""
  for c in "$CLI_SRC" /home/user/code "$(command -v code 2>/dev/null)"; do
    [ -x "$c" ] && { src=$c; break; }
  done
  if [ -z "$src" ]; then
    say "Downloading the CLI (alpine-x64 static build)"
    # curl/wget are absent; use Python.
    python3 - "$CLI" <<'PY'
import os, sys, urllib.request
dst = sys.argv[1]
url = 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64'
r = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(r, timeout=180) as resp, open(dst + '.part', 'wb') as f:
    n = 0
    while True:
        b = resp.read(1 << 20)
        if not b: break
        f.write(b); n += len(b)
os.replace(dst + '.part', dst)
os.chmod(dst, 0o755)
print(f'   ok   {n} bytes -> {dst}')
PY
    # The tarball is a single ./code binary; if we got gzip instead, unpack it.
    if head -c 2 "$CLI" 2>/dev/null | grep -q $'\x1f\x8b'; then
      tmp=$(mktemp -d)
      tar -xzf "$CLI" -C "$tmp" && mv "$tmp/code" "$CLI" && chmod +x "$CLI"
      rm -rf "$tmp"
      ok "unpacked the tarball"
    fi
  else
    cp "$src" "$CLI" && chmod +x "$CLI" && ok "copied from $src"
  fi
  # The alpine build is musl-static, so it runs on this glibc host without libs.
  "$CLI" --version 2>&1 | sed 's/^/   /'
}

# ------------------------------------------------------------------ site server
start_site_server() {
  say "Static site server on :$SITE_PORT (and the live proxy)"
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in *liveproxy*) ok "proxy already running (pid ${p#/proc/})"; return 0 ;; esac
  done
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in *http.server*$SITE_PORT*) kill -9 "${p#/proc/}" 2>/dev/null; echo "   stopped the plain http.server so the proxy can bind :$SITE_PORT" ;; esac
  done
  sleep 1
  if [ ! -f "$SCRIPTS/liveproxy.py" ]; then
    bad "scripts/liveproxy.py missing -- cannot serve same-origin helper endpoints"
    return 1
  fi
  cd "$REPO" || { bad "cannot cd to $REPO (sandbox path quirk)"; return 1; }
  setsid nohup python3 "$SCRIPTS/liveproxy.py" "$REPO" "$SITE_PORT" \
    > /tmp/liveproxy.log 2>&1 < /dev/null &
  sleep 4
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$c" in *liveproxy*) ok "proxy running (pid ${p#/proc/})"; return 0 ;; esac
  done
  bad "proxy did not start; see /tmp/liveproxy.log"
}

# ------------------------------------------------------------------ live helper
boot_live() {
  say "Impeccable live boot"
  cd "$REPO" || { bad "cannot cd to $REPO (sandbox path quirk)"; return 1; }
  IMPECCABLE_HOME=$ENGINE_HOME "$LAUNCHER" live 2>&1 | python3 -c "
import sys, json
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    print(raw[:600]); sys.exit(0)
if not d.get('ok'):
    print('   FAIL', json.dumps({k: d.get(k) for k in ('error','path')}))
    sys.exit(1)
print('   ok   helper on port %s, projectRoot %s' % (d.get('serverPort'), d.get('projectRoot')))
print('        pageFiles %s' % d.get('pageFiles'))
print('        product/design/surfaceBrief: %s/%s/%s  configDrift: %s' % (
    d.get('hasProduct'), d.get('hasDesign'), d.get('hasSurfaceBrief'), d.get('configDrift')))
" || warn "live boot reported a problem"

  # `impeccable live` leaves an extra idle helper behind on some runs; only the
  # pid in server.json owns the port, so kill the rest.
  auth=$(python3 -c "import json;print(json.load(open('$REPO/.impeccable/live/server.json'))['pid'])" 2>/dev/null)
  if [ -n "${auth:-}" ]; then
    for p in /proc/[0-9]*; do
      q=${p#/proc/}
      c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
      case "$c" in *live-server*) [ "$q" != "$auth" ] && kill -9 "$q" 2>/dev/null && echo "   killed stray helper $q (authoritative is $auth)" ;; esac
    done
  fi
}

# ----------------------------------------------------------------------- tunnel
start_tunnel() {
  say "Tunnel service"
  if [ ! -f "$SCRIPTS/tunnel-service.sh" ]; then
    warn "tunnel-service.sh missing; skipping"
    return 0
  fi
  CLI=$CLI sh "$SCRIPTS/tunnel-service.sh" status | sed 's/^/   /'
  echo
  echo "   Start it with:  CLI=$CLI sh $SCRIPTS/tunnel-service.sh start"
  echo "   Deliberately NOT auto-started: a first connect spawns VS Code Server,"
  echo "   so confirm the extension trim above succeeded before you spend the memory."
}

# ------------------------------------------------------------------- connectivity
report_urls() {
  say "How to reach it"
  cat <<EOF
   The injected script points at the absolute URL http://localhost:$HELPER_PORT/live.js.
   Over an HTTPS devtunnels origin that fails twice: mixed content, and
   localhost resolves to the viewer's own machine. So do NOT open the site on a
   bare devtunnels URL expecting the picker to work.

   scripts/liveproxy.py is what fixes it. It serves the pages AND reverse-proxies
   every helper endpoint from one origin, rewriting live.js's hardcoded
   localhost URLs in flight (22 -> 1, the survivor is inside a comment). It also
   rewrites the injected <script src> on the way out, so the HTML on disk keeps
   the normal injection and live-inject still works.

   Therefore: forward port $SITE_PORT only. Port $HELPER_PORT does not need
   forwarding -- everything rides the $SITE_PORT origin. Then open
       http://localhost:$SITE_PORT/blogs.html
   either through the forwarded port or via Simple Browser inside VS Code.
EOF
}

# ------------------------------------------------------------------------ main
if [ "${1:-}" = "--status" ]; then
  check_memory
  [ -f "$SCRIPTS/trim-extensions.sh" ] && sh "$SCRIPTS/trim-extensions.sh" status
  [ -f "$SCRIPTS/tunnel-service.sh" ] && CLI=$CLI sh "$SCRIPTS/tunnel-service.sh" status
  exit 0
fi

check_memory
place_cli
fetch_engine
prep_launcher
trim_extensions
start_site_server
boot_live
start_tunnel
report_urls

say "Done"
echo "   Next: read AGENTS.md, then start the tunnel and forward port $SITE_PORT."
echo "   After any accept, commit with:"
echo "       sh $SCRIPTS/auto-commit.sh \"message\""
