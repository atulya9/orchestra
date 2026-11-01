#!/usr/bin/env bash
# Install orchestra from this checkout: the CLI and skills are symlinked, so pulling the repo updates
# them. Safe to re-run. Never overwrites your config; existing non-link files are moved aside first.
#   ./install.sh [--dry-run]
# Env: ORCHESTRA_BIN_DIR (~/.local/bin), ORCHESTRA_AGENTS_DIR (~/.agents),
#      XDG_CONFIG_HOME (~/.config), ORCHESTRA_SKILL_LINKS (extra skill dirs, space separated)
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${ORCHESTRA_BIN_DIR:-$HOME/.local/bin}"
AGENTS_DIR="${ORCHESTRA_AGENTS_DIR:-$HOME/.agents}"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/orchestra"
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY=""; [ "${1:-}" = "--dry-run" ] && DRY=1

say() { echo "  $*"; }
run() { if [ -n "$DRY" ]; then say "would: $*"; else "$@"; fi; }

# link <source> <target>: point target at source; a different file or dir already there is
# removed when identical, else moved to <target>.bak-<stamp>.
link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    [ "$(readlink "$dst")" = "$src" ] && { say "ok      $dst"; return; }
    run rm "$dst"
  elif [ -e "$dst" ]; then
    if diff -rq "$src" "$dst" >/dev/null 2>&1; then run rm -rf "$dst"
    else run mv "$dst" "$dst.bak-$STAMP"; say "backup  $dst.bak-$STAMP"; fi
  fi
  run mkdir -p "$(dirname "$dst")"
  run ln -s "$src" "$dst"
  say "linked  $dst -> $src"
}

# copy_new <source> <target>: only when the target doesn't exist yet.
copy_new() {
  if [ -e "$2" ]; then say "kept    $2"; else run mkdir -p "$(dirname "$2")"; run cp "$1" "$2"; say "created $2"; fi
}

echo "orchestra $(sed -n 's/^VERSION="\(.*\)"/\1/p' "$REPO/bin/orchestra") from $REPO"

echo "CLI"
chmod +x "$REPO/bin/orchestra"
link "$REPO/bin/orchestra" "$BIN_DIR/orchestra"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) say "note    $BIN_DIR is not on PATH" ;; esac

echo "Skills"
skill_dirs="$AGENTS_DIR/skills"
for d in "$HOME/.claude" "$HOME/.codex"; do [ -d "$d" ] && skill_dirs="$skill_dirs $d/skills"; done
skill_dirs="$skill_dirs ${ORCHESTRA_SKILL_LINKS:-}"
for s in "$REPO"/skills/*/; do
  s="$(basename "$s")"
  link "$REPO/skills/$s" "$AGENTS_DIR/skills/$s"
  for d in $skill_dirs; do
    [ "$d" = "$AGENTS_DIR/skills" ] || link "$AGENTS_DIR/skills/$s" "$d/$s"
  done
done

echo "Config ($CONF_DIR)"
copy_new "$REPO/templates/models.conf" "$CONF_DIR/models.conf"
for f in "$REPO"/templates/harness/*.conf; do copy_new "$f" "$CONF_DIR/harness/$(basename "$f")"; done

echo "Agent instructions"
md="$AGENTS_DIR/AGENTS.md"
if [ -f "$md" ] && grep -q '<!-- orchestra:begin -->' "$md"; then
  # Replace the block between the markers with the current snippet.
  if [ -z "$DRY" ]; then
    awk -v snip="$REPO/AGENTS.md.snippet" '
      /<!-- orchestra:begin -->/ { while ((getline l < snip) > 0) print l; skip = 1; next }
      /<!-- orchestra:end -->/ { skip = 0; next }
      !skip { print }' "$md" >"$md.tmp.$$" && mv "$md.tmp.$$" "$md"
  fi
  say "updated $md"
else
  if [ -z "$DRY" ]; then mkdir -p "$AGENTS_DIR"; { [ -s "$md" ] && echo; cat "$REPO/AGENTS.md.snippet"; } >>"$md"; fi
  say "added   $md"
fi
[ -d "$HOME/.claude" ] && ! grep -qs "$md\|~/.agents/AGENTS.md" "$HOME/.claude/CLAUDE.md" &&
  say "note    Claude Code doesn't load it yet: add '@~/.agents/AGENTS.md' to ~/.claude/CLAUDE.md"
[ -d "$HOME/.codex" ] && [ ! -e "$HOME/.codex/AGENTS.md" ] &&
  say "note    Codex doesn't load it yet: ln -s $md ~/.codex/AGENTS.md"

echo "Next: orchestra docker build   (worker image; then orchestra docker login <kind> for each CLI you use)"
echo "      orchestra models doctor"
