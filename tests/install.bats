#!/usr/bin/env bats
# install.sh against a throwaway HOME.
REPO="$BATS_TEST_DIRNAME/.."

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  unset XDG_CONFIG_HOME ORCHESTRA_BIN_DIR ORCHESTRA_AGENTS_DIR ORCHESTRA_SKILL_LINKS
  mkdir -p "$HOME/.claude" "$HOME/.codex"
}

@test "fresh install links the CLI and skills and seeds config" {
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.local/bin/orchestra")" = "$(cd "$REPO" && pwd)/bin/orchestra" ]
  [ -L "$HOME/.agents/skills/orchestrate" ]
  [ "$(readlink "$HOME/.claude/skills/orchestrate")" = "$HOME/.agents/skills/orchestrate" ]
  [ "$(readlink "$HOME/.codex/skills/orchestrate")" = "$HOME/.agents/skills/orchestrate" ]
  [ -f "$HOME/.config/orchestra/models.conf" ]
  [ -f "$HOME/.config/orchestra/harness/claude.conf" ]
  grep -q '<!-- orchestra:begin -->' "$HOME/.agents/AGENTS.md"
}

@test "re-running keeps config and replaces the AGENTS block in place" {
  "$REPO/install.sh" >/dev/null
  echo "cheap = mine/model" >"$HOME/.config/orchestra/models.conf"
  printf '# Mine\n\n%s\n\n## After\n' "$(cat "$HOME/.agents/AGENTS.md")" >"$HOME/.agents/AGENTS.md"
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.config/orchestra/models.conf")" = "cheap = mine/model" ]
  [ "$(grep -c 'orchestra:begin' "$HOME/.agents/AGENTS.md")" -eq 1 ]
  grep -q '^# Mine' "$HOME/.agents/AGENTS.md"
  grep -q '^## After' "$HOME/.agents/AGENTS.md"
}

@test "an existing different skill dir is backed up, an identical one replaced" {
  mkdir -p "$HOME/.agents/skills/orchestrate" "$HOME/.agents/skills/xreview"
  echo old >"$HOME/.agents/skills/orchestrate/SKILL.md"
  cp "$REPO/skills/xreview/SKILL.md" "$HOME/.agents/skills/xreview/"
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.agents/skills/orchestrate" ]
  ls -d "$HOME"/.agents/skills/orchestrate.bak-* >/dev/null
  [ -L "$HOME/.agents/skills/xreview" ]
  ! ls -d "$HOME"/.agents/skills/xreview.bak-* 2>/dev/null
}

@test "dry run changes nothing" {
  run "$REPO/install.sh" --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.local/bin/orchestra" ]
  [ ! -e "$HOME/.config/orchestra" ]
}
