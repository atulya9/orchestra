# Shared setup: an isolated config dir and a clean harness environment for every test.
ORCH="$BATS_TEST_DIRNAME/../bin/orchestra"
FIX="$BATS_TEST_DIRNAME/fixtures"

setup_env() {
  unset CLAUDECODE CODEX_THREAD_ID CODEX_SESSION_ID GROK_SESSION_ID ANTIGRAVITY_CONVERSATION_ID \
    OPENCODE_SESSION_ID ORCHESTRA_LEAD ORCHESTRA_RUNTIME ORCHESTRA_TIMEOUT ORCHESTRA_HARNESS_DIR
  export ORCHESTRA_CONFIG="$BATS_TEST_TMPDIR/conf/models.conf"
  mkdir -p "$BATS_TEST_TMPDIR/conf/harness" "$BATS_TEST_TMPDIR/work"
  cat >"$ORCHESTRA_CONFIG" <<'EOF'
# test config
cheap    = claude/haiku#max
build    = grok/grok-x#high, claude/sonnet#medium
review   = claude/opus#medium
runtime  = host
EOF
  cd "$BATS_TEST_TMPDIR/work"
}

harness() { cat >"$BATS_TEST_TMPDIR/conf/harness/$1.conf"; }
