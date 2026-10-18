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

# Emit the file with the inject tag removed, to stdout.
descaffold() {
  python3 - "$REPO/$1" "$1" <<'PY'
import re, sys
path, rel = sys.argv[1], sys.argv[2]
s = open(path, encoding='utf-8').read()
# Only HTML that actually carries the tag as a live artifact. Without this guard
# the regex also ate a FENCED EXAMPLE of the tag out of AGENTS.md, so a commit
# went out with three lines of documentation silently missing while the working
# file still looked correct -- index-based staging means the damage is invisible
# to git status.
if rel.endswith('.html') and '</body>' in s:
    s = re.sub(r'[ \t]*<!-- impeccable-live-start -->.*?<!-- impeccable-live-end -->\n', '', s, flags=re.S)
    s = s.replace('\n</body>\n</html>', '\n  </body>\n</html>')
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
