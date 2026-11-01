#!/usr/bin/env bats
load helpers

setup() { setup_env; }

@test "lead is detected from each harness's env" {
  [ "$(CLAUDECODE=1 "$ORCH" models list | grep 'lead agent')" = "  lead agent      claude" ]
  [ "$(CODEX_THREAD_ID=x "$ORCH" models list | grep 'lead agent')" = "  lead agent      codex" ]
  [ "$(CODEX_SESSION_ID=x "$ORCH" models list | grep 'lead agent')" = "  lead agent      codex" ]
  [ "$(GROK_SESSION_ID=x "$ORCH" models list | grep 'lead agent')" = "  lead agent      grok" ]
  [ "$(ORCHESTRA_LEAD=agy CLAUDECODE=1 "$ORCH" models list | grep 'lead agent')" = "  lead agent      agy" ]
  [ "$("$ORCH" models list | grep 'lead agent')" = "  lead agent      other" ]
}

@test "global config applies when the harness has no file" {
  run env CLAUDECODE=1 "$ORCH" models get build
  [ "$status" -eq 0 ]
  [ "$output" = "grok/grok-x#high" ]
}

@test "harness file overrides global for its lead only" {
  harness codex <<<'build = codex/model-a#high'
  [ "$(CODEX_THREAD_ID=x "$ORCH" models get build)" = "codex/model-a#high" ]
  [ "$(CLAUDECODE=1 "$ORCH" models get build)" = "grok/grok-x#high" ]
  [ "$("$ORCH" models get build --harness codex)" = "codex/model-a#high" ]
}

@test "list tags harness values and shows the harness file" {
  harness claude <<<'lead.explore = haiku#max'
  run env CLAUDECODE=1 "$ORCH" models list
  [[ "$output" == *"harness: $BATS_TEST_TMPDIR/conf/harness/claude.conf"* ]]
  [[ "$output" == *"lead.explore    haiku#max  [harness]"* ]]
  [[ "$output" == *"review          claude/opus#medium"* ]]
  [[ "$output" != *"review          claude/opus#medium  ["* ]]
}

@test "lead roles missing for a harness fail clearly" {
  harness claude <<<'lead.explore = haiku#max'
  run env GROK_SESSION_ID=x "$ORCH" models get lead.explore
  [ "$status" -ne 0 ]
  [[ "$output" == *"no models configured for role 'lead.explore'"* ]]
}

@test "set --harness writes the current lead's file, or a named one" {
  CODEX_THREAD_ID=x "$ORCH" models set --harness build codex/a#low codex/b
  grep -qx 'build    = codex/a#low, codex/b' "$BATS_TEST_TMPDIR/conf/harness/codex.conf"
  "$ORCH" models set --harness claude lead.task opus#high
  grep -qx 'lead.task = opus#high' "$BATS_TEST_TMPDIR/conf/harness/claude.conf"
  # global untouched
  ! grep -q 'codex/' "$ORCHESTRA_CONFIG"
}

@test "set without a flag still writes global" {
  "$ORCH" models set review claude/sonnet
  grep -qx 'review   = claude/sonnet' "$ORCHESTRA_CONFIG"
}

@test "project config beats harness and global" {
  git init -q .
  mkdir -p .orchestra
  echo 'build = opencode/x/y' >.orchestra/models.conf
  harness codex <<<'build = codex/model-a#high'
  [ "$(CODEX_THREAD_ID=x "$ORCH" models get build)" = "opencode/x/y" ]
  run env CODEX_THREAD_ID=x "$ORCH" models list
  [[ "$output" == *"opencode/x/y  [project]"* ]]
}

@test "unknown harness names are rejected" {
  run "$ORCH" models list --harness nope
  [ "$status" -ne 0 ]
}

@test "doctor explains an unconfigured install instead of failing on missing CLIs" {
  printf 'runtime = host\n' >"$ORCHESTRA_CONFIG"
  run env PATH=/usr/bin:/bin "$ORCH" models doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"no worker roles configured yet"* ]]
}
