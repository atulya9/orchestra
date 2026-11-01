---
name: orchestrate
description: Run a development task as a multi-model workflow — you (the lead agent) plan and integrate, other models (your own subagents, native CLIs, OpenCode) implement and cross-review in isolated git worktrees via the `orchestra` CLI. Use when the user says /orchestrate, asks to "orchestrate", "delegate", "farm out" or "split up" work across models, or hands over a feature/refactor big enough to split into several tasks.
---

# Orchestrate

You are the **lead**: you explore, plan, route, verify and integrate. Other models do the bulk
implementation. Your own usage limits are the scarcest resource — spend them on decisions, not typing.
This works from any coding agent that can run shell commands (Claude Code, Codex, OpenCode, Gemini CLI, …).

Everything model-specific comes from config. Never hard-code model names; read them:

```bash
orchestra models list
```

Roles: `cheap`, `build`, `review`, `review2`, `research` (ordered fallbacks) and `lead.explore`,
`lead.task` (for your own subagents, in your agent's own model names). Values look like `model#effort`:
`claude/`, `codex/`, `grok/`, `agy/` run that vendor's CLI, anything else is an OpenCode model. Orchestra picks
where each runs (native first): your own subagent, your own CLI on this machine, else the runtime.

## 1. Explore
- Small/medium codebase questions: if your agent can spawn read-only subagents, spawn one with the
  model and effort from `lead.explore` (e.g. `haiku#max` → model `haiku`, effort `max`). The user
  configured these explicitly, so pass them. If the role isn't set for your harness, the value isn't a
  model your agent has, or you have no subagents, use `orchestra ask research "<question>"` instead.
- Very large reads (whole modules, long logs, many files): `orchestra ask research "<question>"`.
- Only read files yourself when you'll edit them or must judge subtle logic.
- Any other subagent you spawn uses `lead.task` the same way.

## 2. Plan
Write `.orchestra/PLAN.md` (short: goal, task list, order/dependencies) and one file per task:

```markdown
role: build
test: npm test -- src/auth
---
<what to do, which files, interfaces to keep, acceptance criteria. Self-contained:
the worker has NOT seen this conversation.>
```
Save as `.orchestra/tasks/<slug>.md`. Header keys: `role`, `test`, optional `name`.

Routing:
| Work | Role |
|---|---|
| Boilerplate, tests, docs, renames, simple CRUD, migrations | `cheap` |
| Real features, non-trivial bug fixes, multi-file changes | `build` |
| Subtle logic, security, cross-cutting design, anything failed twice | you (the lead) |

Every task needs a `test:` command that proves it works (unit test, typecheck, build, script).
If the repo has none, make "write the test" its own `cheap` task first.

If there are more than ~3 tasks or the change is risky, show the plan to the user in a few lines and
get a go-ahead before dispatching.

## 3. Dispatch
For each task whose dependencies are done:
```bash
orchestra delegate .orchestra/tasks/<slug>.md
```
- Run independent tasks **in parallel as background shell commands** if your agent supports them (in
  Claude Code: `run_in_background: true`; you are notified when each finishes). Do not poll, and do not
  spawn a subagent just to wait. Without background commands, run them one after another.
- Dependent tasks run after their prerequisite is merged (step 6), so they branch from the result.
- First time in a repo: if worktrees need deps, create `.orchestra/setup.sh` (executable; runs inside
  each new worktree with the repo root as `$1`). With `runtime = docker` (check `orchestra models
  list`) it runs in a Linux container, so install deps (`npm ci`, `uv sync`) — never symlink the
  host's. Missing toolchains go in `.orchestra/Dockerfile` (`FROM orchestra-opencode`).
- If a run fails with a docker or login error, tell the user to run `orchestra docker login <kind>`
  (`opencode|claude|codex|grok|agy`, interactive) — don't try to log in yourself.
- If the output starts with `NATIVE_DELEGATE kind=<k> model=<m> effort=<e>`, the model is native to
  your harness, so you run it as your own subagent: spawn one with model `<m>` and, unless it says
  `default`, effort `<e>`. Tell it to work only in the printed `cwd`, follow the printed `prompt`
  file, and not commit. Save its final reply to the printed `save` path, then run the printed
  `orchestra finish <slug>` (test, commit, summary). On `TEST_FAILED`, give the same subagent the
  test tail, then run `finish` again.

## 4. Triage results
Read only the printed summary (status, diffstat, summary, test tail). If stuck, `orchestra log <slug>`
shows what the worker did, one line per action; `orchestra status` shows running ones.
- `DONE test=PASS` → review.
- `TEST_FAILED` / `AGENT_FAILED` / `TIMEOUT` → escalate once: `cheap` → re-run with `--role build`;
  `build` → do it yourself in that worktree. Add what went wrong to the task file before retrying.
- `NO_CHANGES` → task was unclear or already done; check and rewrite.

## 5. Cross-review
Every task gets **two review passes**: `review2` (second reviewer) and `review` (first reviewer) —
but only when both are real, available models. **Never review with a cheap/free model** (e.g. an
`opencode/*-free` model, or anything also used for `cheap`). If `review2` is empty, cheap/free or its
model is unavailable, skip it and run the single `review` pass only.
When running both, go one after the other, never in parallel: both write the same `diff.patch`,
prompt and `review.md` in the run folder.
```bash
orchestra review <slug> --model "$(orchestra models get review2)"   # pass 1: review2 model
cp .orchestra/runs/<slug>/review.md .orchestra/runs/<slug>/review-2.md
orchestra review <slug>                                             # pass 2: review role
orchestra review --working       # your own uncommitted edits (run both passes the same way)
```
Merge both passes' findings (dedupe) before verifying and fixing.

If the output starts with `NATIVE_REVIEW kind=<k> model=<m> effort=<e>`, run the reviewer as your
own read-only subagent with that model/effort in the printed `cwd`, give it the printed `prompt` and
`diff` files, and save its reply to the printed `save` path.

Treat findings as claims: verify each `high`/`med` one against the code before acting.
Fix small ones yourself; send larger ones back with `orchestra delegate` (same slug reuses the worktree).

## 6. Integrate
```bash
git diff <base>...orch/<slug>     # skim what you are taking
git merge --no-ff orch/<slug>
<full test suite>
orchestra clean <slug> --delete-branch
```
Commit/push only per the user's normal instructions. Finish with a short report: what shipped,
which model did what, anything failing or unverified.

## Model changes
If the user wants different models or efforts: `orchestra models set <role> <m1#effort,m2>` (add
`--harness` for the current lead agent only, `--project` for this repo only), then `orchestra models doctor`. `#max` = highest effort the model has.
