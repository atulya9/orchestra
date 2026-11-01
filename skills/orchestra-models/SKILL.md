---
name: orchestra-models
description: Show or change which models and effort levels the orchestra workflow uses for each role (cheap, build, review, review2, research, lead.explore, lead.task). Use for /orchestra-models, or when the user says a model is unavailable, wants to swap models, or change reasoning effort.
---

# Orchestra models

```bash
orchestra models list [--harness <name>]               # routing for this lead (or another harness)
orchestra models doctor                                # check each model exists, show resolved effort
orchestra models set <role> <m1#effort,m2#effort>      # change global preference (ordered fallbacks)
orchestra models set --harness [name] <role> <m1,...>  # override for one lead agent (default: the current one)
orchestra models set --project <role> <m1,...>         # override for this repo only
opencode models                                        # OpenCode models (agy models / grok models for those CLIs)
```

- Values are `kind/model#effort`: `claude/`, `codex/`, `grok/`, `agy/` run that vendor's CLI; anything else is
  an OpenCode `provider/model`. No suffix uses the default. `#max` resolves via OpenCode's model cache.
- Lookup order, first match wins: `<repo>/.orchestra/models.conf` (`--project`), then
  `~/.config/orchestra/harness/<lead>.conf` (`--harness`), then the global `models.conf`. `models list`
  tags values that come from an override with `[project]` / `[harness]`.
- `lead.*` roles are for the lead agent's own subagents, in that agent's model names plus effort,
  e.g. `lead.explore = haiku#max` for Claude Code. They belong in the harness file (`--harness`), so each
  lead agent keeps its own.
- Native first: a model of the lead's own kind runs as the lead's subagent (Claude Code) or as the
  lead's CLI on the host (Codex, Grok, agy, OpenCode); others run in the runtime. Lead is detected from
  the harness env; override with `ORCHESTRA_LEAD=claude|codex|grok|agy|opencode|other`.
- After changing anything, run `orchestra models doctor` and report the result.
- If a model the user names isn't listed by its CLI, say so and suggest the closest one listed.
