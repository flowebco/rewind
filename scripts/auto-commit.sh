#!/bin/sh
# Commit accepted live-mode work without dragging in the temporary scaffolding,
# and without ever touching the working files.
#
# The problem: `impeccable live-inject` puts a dev-only tag in every patched page
#   <!-- impeccable-live-start --><script src="http://localhost:8400/...">...
# `live-server stop` strips it again, so it must never reach a commit -- but it
# lives in the very files we edit, so `git add -A` would commit it.
#
# An earlier version of this script removed the tag from disk, committed, then
# put it back. That is unsafe here: writes under the workspace path fail
# intermittently from spawned processes, and a failed restore silently kills the
# live session. So this version stages content straight into the index with
# `git hash-object -w` + `git update-index --cacheinfo`. The working tree keeps
# the tag, the live session keeps running, and the commit stays clean.
#
# Usage: sh scripts/auto-commit.sh "commit message" [file ...]
#        sh scripts/auto-commit.sh --dry-run
# Run from the repo root. With no file list it considers the product surface:
#   *.html  css/*.css  js/*.js  DESIGN.md  PRODUCT.md  README.md  AGENTS.md
# It never stages .impeccable session state, the engine cache, or scripts/.

set -eu

# REPO defaults to the caller's cwd: inside this sandbox a spawned process cannot
# reliably resolve an absolute workspace path via cd, dirname "$0", or git -C.
REPO=${REPO:-$PWD}
G="git -C $REPO"
[ -f "$REPO/blogs.html" ] && [ -d "$REPO/.git" ] || {
  echo "auto-commit.sh: $REPO does not look like the repo root." >&2
  echo 'usage: cd <repo> && sh scripts/auto-commit.sh "message"' >&2
  exit 2
}

DEFAULT_FILES="index.html blogs.html blog.html css/styles.css css/blog.css js/app.js js/blog.js DESIGN.md PRODUCT.md README.md AGENTS.md"
AUTHOR_NAME=${GIT_AUTHOR_NAME:-impeccable-live}
AUTHOR_MAIL=${GIT_AUTHOR_EMAIL:-live@local}

DRY=0
[ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }

if [ "$DRY" = 1 ]; then
  # `$*` is empty when a message is given with no file list, and this once
  # committed only a pre-staged file and silently dropped the markup that went
  # with it -- leaving HEAD with new CSS and old HTML. Test the count.
  if [ "$#" -gt 0 ]; then FILES="$*"; else FILES="$DEFAULT_FILES"; fi
else
  MSG=${1:?usage: auto-commit.sh "commit message" [file ...]}
  shift
  # `$*` is empty when a message is given with no file list, and this once
  # committed only a pre-staged file and silently dropped the markup that went
  # with it -- leaving HEAD with new CSS and old HTML. Test the count.
  if [ "$#" -gt 0 ]; then FILES="$*"; else FILES="$DEFAULT_FILES"; fi
fi

# Live-mode guard: variants/carbonize wrappers are ephemeral (display: contents
# shows all 5 panes outside a session). Committing one baked the dceb938c
# 5× duplication into main and made every future live-wrap fail with
# element_ambiguous. Refuse the commit until the session is finished.
for f in $FILES; do
  [ -f "$REPO/$f" ] || continue
  if grep -q "impeccable-variants-start\|impeccable-carbonize-start" "$REPO/$f" 2>/dev/null; then
    echo "auto-commit: $f contains a live variants/carbonize wrapper -- finish or discard the live session first (impeccable live-complete) and run again." >&2
    echo "Refusing to commit ephemeral live scaffolding." >&2
    exit 2
  fi
done

# Emit the file with live-mode scaffolding removed, to stdout.
# Strips (1) the dev-only live-inject tag and (2) any variants/carbonize
# wrapper that is only valid while `impeccable live` is cycling. The wrapper
# uses `display: contents` so outside a session all 5 panes are visible at
# once -- exactly the "5 identical cards" bug that was committed as dceb938c
# and then made every future `live-wrap` fail with `element_ambiguous`.
# We do not try to auto-unwrap to "original" here: the correct fix is to
# finish the session (accept/discard + live-complete), not to guess.
descaffold() {
  python3 - "$REPO/$1" "$1" <<'PY'
import re, sys
path, rel = sys.argv[1], sys.argv[2]
s = open(path, encoding='utf-8').read()
# Guard the live-inject example in AGENTS.md: only strip the tag when it is a
# real HTML page with a closing body.
if rel.endswith('.html') and '</body>' in s:
    s = re.sub(r'[ \t]*<!-- impeccable-live-start -->.*?<!-- impeccable-live-end -->\n', '', s, flags=re.S)
    s = s.replace('\n</body>\n</html>', '\n  </body>\n</html>')
    # Variants wrapper is ephemeral: <!-- impeccable-variants-start ID --> ... <!-- end -->
    # and its <style data-impeccable-css>. Outside a session all 5 variants
    # are visible, and the next scaffold fails with element_ambiguous.
    # Carbonize is the same: must be cleaned via live-complete, not committed.
    # Do not silently unwrap -- abort the commit so the session is finished.
    if 'impeccable-variants-start' in s or 'impeccable-carbonize-start' in s:
        sys.stderr.write(f"auto-commit: {rel} still contains a live variants/carbonize wrapper -- finish or discard the live session first (live-complete) and run again.\n")
        sys.exit(2)
sys.stdout.write(s)
PY
}

changed=""
for f in $FILES; do
  [ -f "$REPO/$f" ] || continue
  # What HEAD has for this file, or empty when it is new.
  if $G cat-file -e "HEAD:$f" 2>/dev/null; then
    head_sha=$($G rev-parse "HEAD:$f")
  else
    head_sha=""
  fi
  new_sha=$(descaffold "$f" | $G hash-object --stdin -w)
  if [ "$new_sha" != "$head_sha" ]; then
    changed="$changed $f:$new_sha"
  fi
done

if [ -z "$changed" ]; then
  echo "nothing to commit: every product file already matches HEAD once the"
  echo "live-mode inject tag is excluded."
  exit 0
fi

echo "would commit:"
for entry in $changed; do
  f=${entry%%:*}
  printf '  %s\n' "$f"
done
if [ "$DRY" = 1 ]; then
  echo "(dry run -- index untouched)"
  exit 0
fi

for entry in $changed; do
  f=${entry%%:*}
  sha=${entry##*:}
  $G update-index --add --cacheinfo 100644,"$sha","$f"
done

echo "staged:"
$G diff --cached --name-only | sed 's/^/  /'

$G -c user.name="$AUTHOR_NAME" -c user.email="$AUTHOR_MAIL" commit -q -m "$MSG"
echo "committed $($G rev-parse --short HEAD)"
$G log --oneline -1
echo
echo "Working tree still carries the live-mode inject tag, as intended:"
$G status --porcelain | sed 's/^/  /'
