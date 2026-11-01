# Changelog

## 0.2.0 — 2026-11-01

- Per-harness model config: `~/.config/orchestra/harness/<lead>.conf` sits between the project and
  global configs. `orchestra models set --harness [name]`, and `list|get|doctor --harness <name>`.
  `models list` tags values that come from an override.
- Codex as a lead (detected from `CODEX_THREAD_ID` / `CODEX_SESSION_ID`) and as a worker
  (`codex/<model>#<effort>`): `codex exec --json`, session ids for `attach`, `orchestra log` support,
  usage-limit and auth errors fall through to the next model, `docker login codex`.
- `models doctor` checks Codex models and efforts against the logged-in account's catalog.
- First repository release: `install.sh`, bats tests, CI (Linux + macOS Bash 3.2).
- Generic defaults: the config template ships with commented examples instead of preset models;
  `models doctor` explains an unconfigured install and only needs `opencode` when a role uses it.
- Linux hosts: falls back to `sha256sum` and `/proc` UUIDs when `shasum` / `uuidgen` are missing.

## 0.1.0

- Initial version: delegate / finish / review / ask / status / log / attach / clean, Claude Code,
  Grok, agy and OpenCode workers, Docker runtime.
