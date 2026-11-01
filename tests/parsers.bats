#!/usr/bin/env bats
# Each CLI's streaming JSON -> reply text (agent_text), one line per action (pretty), session id.
load helpers

setup() {
  setup_env
  # shellcheck source=../bin/orchestra
  source "$ORCH"
}

session_id() { jq -R -r 'fromjson? | objects | (.conversation_id // .sessionID // .thread_id // empty)' "$1" | head -1; }

@test "codex: reply text, actions, session id; stdin notice dropped" {
  run agent_text codex "$FIX/codex.jsonl"
  [[ "$output" == *"SUMMARY:"* ]]
  [[ "$output" != *"Reading additional input"* ]]
  run pretty codex /repo/.orchestra/worktrees/fix-add <"$FIX/codex.jsonl"
  [[ "$output" == *"→ shell "* ]]
  [[ "$output" == *"→ edit calc.py"* ]]
  [[ "$output" == *"✓ done"* ]]
  [[ "$output" != *"Reading additional input"* ]]
  [ "$(session_id "$FIX/codex.jsonl")" = "01a19529-277f-7bc0-9186-be6c3bfaafc8" ]
}

@test "codex: turn.failed surfaces as an error the fallback check can see" {
  printf '%s\n' '{"type":"thread.started","thread_id":"t1"}' \
    '{"type":"turn.failed","error":{"message":"You have hit your usage limit"}}' >"$BATS_TEST_TMPDIR/f.jsonl"
  run agent_text codex "$BATS_TEST_TMPDIR/f.jsonl"
  [[ "$output" == *"usage limit"* ]]
  echo "$output" | grep -Eqi "$FALLBACK_RE"
}

@test "grok: text fragments joined, tool calls listed" {
  run agent_text grok "$FIX/grok.jsonl"
  [[ "$output" == *"All good."* ]]
  run pretty grok <"$FIX/grok.jsonl"
  [[ "${lines[0]}" == "→ run_terminal_command npm test" ]]
  [[ "$output" == *"✓ end_turn"* ]]
}

@test "claude: result text and tool uses" {
  run agent_text claude "$FIX/claude.jsonl"
  [[ "$output" == *"SUMMARY:"* ]]
  run pretty claude <"$FIX/claude.jsonl"
  [[ "$output" == *"→ Bash ls"* ]]
  [[ "$output" == *"✓ success"* ]]
}

@test "non-JSON output is kept and marked" {
  printf 'boom: something broke\n' >"$BATS_TEST_TMPDIR/raw.jsonl"
  run pretty codex <"$BATS_TEST_TMPDIR/raw.jsonl"
  [ "$output" = "! boom: something broke" ]
}

@test "model kinds" {
  [ "$(model_kind codex/model-a#high)" = codex ]
  [ "$(model_kind claude/opus)" = claude ]
  [ "$(model_kind opencode/model-b#max)" = opencode ]
  [ "$(model_kind openrouter/foo/bar)" = opencode ]
}

@test "placement: the lead's own kind runs natively" {
  [ "$(CLAUDECODE=1 placement claude/opus)" = subagent ]
  [ "$(CODEX_THREAD_ID=x placement codex/model-a)" = host ]
  [ "$(CODEX_THREAD_ID=x placement claude/opus)" = runtime ]
}
