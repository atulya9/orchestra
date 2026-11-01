---
name: delegate
description: Hand one well-defined coding task to another model (the cheap or build role) in its own git worktree via `orchestra delegate`, then report the result. Use for /delegate, or when the user asks to give a single task to GPT, Grok, GLM, Gemini or "a cheaper model".
---

# Delegate one task

1. Pick the role: `cheap` for mechanical work (tests, docs, boilerplate), `build` for real features.
   If the user named a specific model, use `--model kind/model#effort` instead (`claude/`, `codex/`, `grok/`, `agy/`, or an OpenCode `provider/model`)
   (`orchestra models list` shows what's configured).
2. Write `.orchestra/tasks/<slug>.md`:
   ```markdown
   role: cheap
   test: <command that proves it works>
   ---
   <self-contained instructions: goal, files, constraints, acceptance criteria>
   ```
3. Run it as a background shell command if your agent supports that, and wait for the notification
   (don't poll); otherwise run it in the foreground:
   ```bash
   orchestra delegate .orchestra/tasks/<slug>.md
   ```
   If the output starts with `NATIVE_DELEGATE kind=<k> model=<m> effort=<e>`, spawn your own
   subagent with that model and, unless `default`, that effort. Tell it to work only in the printed
   `cwd`, follow the printed `prompt` file, and not commit. Save its final reply to the printed
   `save` path, then run the printed `orchestra finish <slug>`.
4. Report the status line, the diffstat and the summary to the user. If the test failed, say so with
   the test tail (and `orchestra log <slug>` if unclear; the user can reopen the worker's session with
   `orchestra attach <slug>`). Offer the next step: `/xreview <slug>`, merging `orch/<slug>`, or escalating
   (`--role build`) on failure.
