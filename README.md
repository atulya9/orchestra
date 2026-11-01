# orchestra

Route coding work from the agent you're using (the **lead**: Claude Code, Codex, Grok Build,
Antigravity/agy, OpenCode) to other models. The lead plans and integrates; workers implement in their
own git worktrees; two different models review. One Bash script, no daemon.

```
lead (your agent) ──orchestra delegate──▶ worker in .orchestra/worktrees/<task>  (branch orch/<task>)
                  ◀── summary, test result, diffstat ──┘
                  ──orchestra review────▶ reviewer (never the author's model)
```

## Install

```bash
git clone https://github.com/atulya9/orchestra.git
orchestra/install.sh                     # --dry-run to preview
```

Then pick models for the roles, using the CLIs you already have (see [Models](#models)):

```bash
orchestra models set build claude/sonnet#high
orchestra models set review claude/opus,codex/<model>#high
orchestra models doctor                  # checks every model and effort
```

With the default Docker runtime, build the worker image and log each CLI in once inside it:

```bash
orchestra docker build                   # claude, codex, grok, agy and opencode CLIs
orchestra docker login claude            # interactive; one per CLI you route work to
```

Prefer your own machine's CLIs and logins? `orchestra models set runtime host` skips Docker.

`install.sh` symlinks `~/.local/bin/orchestra` and the skills (into `~/.agents/skills`, plus
`~/.claude/skills` and `~/.codex/skills`), seeds `~/.config/orchestra/` from `templates/` without
overwriting anything, and keeps the orchestra block in `~/.agents/AGENTS.md` current. Re-run it after
pulling; since everything is linked, edits in this checkout are live.

Needs: bash 3.2+, git, jq, the CLIs of the models you configure, and Docker for the default runtime.
Works on macOS and Linux.

## Commands

| Command | What it does |
|---|---|
| `orchestra delegate <task.md> [--role R \| --model M]` | Run a task in its own worktree/branch, run its test, commit, print a summary |
| `orchestra finish <task>` | After a `NATIVE_DELEGATE` hand-off: test, commit, summarize the lead's own subagent's work |
| `orchestra review <task> \| --working` | Cross-review a task branch (or your uncommitted changes) with a model other than the author |
| `orchestra ask <role\|model> "question"` | Read-only question about the repo |
| `orchestra status` / `log [-f] <task>` | What every task is doing; one line per worker action |
| `orchestra attach <task>` | Reopen a finished worker's session interactively |
| `orchestra models list \| get \| set \| doctor` | Model routing (see below) |
| `orchestra docker build \| login \| shell \| reset-login` | Worker container |
| `orchestra clean <task>... [--delete-branch]` | Remove worktrees |

Task files are Markdown with an optional header (`role:`, `test:`, `name:`), then `---`, then the brief.

## Models

Roles: `cheap`, `build`, `review`, `review2`, `research` (ordered fallbacks) and `lead.explore`,
`lead.task` (the lead's own subagents, in its own model names). Values are `kind/model#effort`:
`claude/`, `codex/`, `grok/`, `agy/` drive that vendor's CLI; anything else is an OpenCode
`provider/model`. A model that's rate-limited, unauthorized or missing falls through to the next one.

Config files, first match wins:

1. `<repo>/.orchestra/models.conf` — one repository (`orchestra models set --project ...`)
2. `~/.config/orchestra/harness/<lead>.conf` — one lead agent (`orchestra models set --harness [name] ...`)
3. `~/.config/orchestra/models.conf` — everything else

The lead is detected from the env its shell commands get: `CLAUDECODE` (Claude Code),
`CODEX_THREAD_ID` / `CODEX_SESSION_ID` (Codex), `GROK_SESSION_ID`, `ANTIGRAVITY_CONVERSATION_ID`,
`OPENCODE_SESSION_ID`; override with `ORCHESTRA_LEAD`.

Where a model runs, native first: the lead's own kind runs as its subagent (Claude Code) or its own CLI
on the host (Codex, Grok, agy); everything else runs in the runtime (`docker` by default: repo mounted
read-only, only the task's worktree writable; or `host`).

## Development

```bash
bats tests/                                   # config lookup, stream parsers, install.sh
shellcheck -S warning bin/orchestra install.sh
```

The parsers for each CLI's streaming JSON are the part most likely to break when a vendor changes its
output; `tests/fixtures/` holds recorded streams. Keep `bin/orchestra` Bash 3.2 compatible (macOS).
Bump `VERSION` in `bin/orchestra` and add a `CHANGELOG.md` entry per release; tag `vX.Y.Z`.

## License

MIT, see [LICENSE](LICENSE).
