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

@test "subagent and native.* overrides control placement and mapped model name" {
  source "$ORCH"
  harness codex <<<'subagent = off'
  [ "$(CODEX_THREAD_ID=x placement codex/model-a)" = host ]

  harness grok <<<'subagent = on'
  [ "$(GROK_SESSION_ID=x placement grok/grok-x)" = subagent ]
  [ "$(GROK_SESSION_ID=x native_model grok/grok-x#high)" = grok-x ]

  # opencode preserves full provider/model when subagent = on
  harness opencode <<<'subagent = on'
  [ "$(OPENCODE_SESSION_ID=x placement openrouter/x-ai/grok-4#high)" = subagent ]
  [ "$(OPENCODE_SESSION_ID=x native_model openrouter/x-ai/grok-4#high)" = openrouter/x-ai/grok-4 ]

  # global native.* does not activate under non-subagent leads
  cat >>"$ORCHESTRA_CONFIG" <<'EOF'
native.claude/sonnet = mapped-sonnet
EOF
  rm -f "$BATS_TEST_TMPDIR/conf/harness/grok.conf"
  [ "$(GROK_SESSION_ID=x placement claude/sonnet#high)" = runtime ]

  # subagent = off disables even explicit native.* mappings
  harness agy <<'EOF'
subagent             = off
native.claude/sonnet = claude-sonnet
EOF
  [ "$(ANTIGRAVITY_CONVERSATION_ID=x placement claude/sonnet#high)" = runtime ]

  harness agy <<'EOF'
native.claude/sonnet = claude-sonnet
native.agy/cli-only  = off
EOF
  [ "$(ANTIGRAVITY_CONVERSATION_ID=x placement claude/sonnet#high)" = subagent ]
  [ "$(ANTIGRAVITY_CONVERSATION_ID=x native_model claude/sonnet#high)" = claude-sonnet ]
  [ "$(ANTIGRAVITY_CONVERSATION_ID=x placement agy/cli-only)" = host ]
  [ "$(ANTIGRAVITY_CONVERSATION_ID=x placement agy/pro#high)" = subagent ]
  [ "$(ANTIGRAVITY_CONVERSATION_ID=x native_model agy/pro#high)" = pro ]

  cat >"$ORCHESTRA_CONFIG" <<'EOF'
build    = claude/sonnet#high, agy/pro
runtime  = host
EOF
  run env ANTIGRAVITY_CONVERSATION_ID=x "$ORCH" models list
  [ "$status" -eq 0 ]
  [[ "$output" != *"native.claude/sonnet"* ]]
  [[ "$output" != *"subagent"* ]]

  run env ANTIGRAVITY_CONVERSATION_ID=x "$ORCH" models doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok      build: claude/sonnet#high (lead's own subagent)"* ]]
  [[ "$output" == *"ok      build: agy/pro (lead's own subagent)"* ]]
  [[ "$output" != *"native.claude/sonnet:"* ]]
  [[ "$output" != *"subagent:"* ]]
}

@test "delegate, review (direct + fallback), and ask emit NATIVE_* handoffs" {
  git init -q .
  echo hi >a.txt
  git add a.txt
  git -c user.name=t -c user.email=t@t commit -qm init
  echo hi2 >>a.txt

  # Stub failing grok CLI so fallback-to-subagent can be exercised.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\necho "429 rate limit"\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/grok"
  chmod +x "$BATS_TEST_TMPDIR/bin/grok"

  harness agy <<'EOF'
native.claude/sonnet = claude-sonnet-native
EOF
  cat >"$ORCHESTRA_CONFIG" <<'EOF'
build    = claude/sonnet#high
review   = grok/grok-x#high, agy/gemini-4-neon-high
research = agy/gemini-4-hydrogen-medium
runtime  = host
EOF

  printf 'role: build\n---\ndo thing\n' >task.md
  run env ANTIGRAVITY_CONVERSATION_ID=x "$ORCH" delegate task.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"NATIVE_DELEGATE kind=agy model=claude-sonnet-native effort=high"* ]]

  # review: grok fails -> falls back to agy/gemini-4-neon-high NATIVE_REVIEW
  run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" ANTIGRAVITY_CONVERSATION_ID=x "$ORCH" review --working
  [ "$status" -eq 0 ]
  [[ "$output" == *"NATIVE_REVIEW kind=agy model=gemini-4-neon-high effort=default"* ]]

  # ask: subagent-placed model emits NATIVE_ASK cleanly without unbound LAST_LOG
  run env ANTIGRAVITY_CONVERSATION_ID=x "$ORCH" ask research "what is a.txt?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NATIVE_ASK kind=agy model=gemini-4-hydrogen-medium effort=default"* ]]
}
