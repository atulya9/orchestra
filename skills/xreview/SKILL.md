---
name: xreview
description: Get a second-opinion code review from the configured review model (your own subagent when it's native to your harness, else a native CLI or OpenCode model) on a delegated orchestra branch or on the current uncommitted changes. Use for /xreview, or when the user asks for a cross-review, second opinion, or "have Grok/GPT/Gemini review this".
---

# Cross-model review

```bash
orchestra review <slug>        # a branch made by `orchestra delegate`
orchestra review --working     # uncommitted changes in the main checkout (e.g. your own edits)
orchestra review --working --base main   # everything since main
```
The reviewer is the first `review` model that differs from the author; force one with
`--model kind/model#effort`. Run it as a background shell command if the diff is large and your
agent supports that.

If the output starts with `NATIVE_REVIEW kind=<k> model=<m> effort=<e>`, run the reviewer as your
own read-only subagent with that model (and effort unless `default`) in the printed `cwd`: give it
the printed `prompt` and `diff` files and save its reply to the printed `save` path.

Then:
1. Verify each `high`/`med` finding against the actual code — reviewers hallucinate. Drop false ones.
2. Present the confirmed findings to the user, most severe first, with your verdict on each.
3. Offer to fix them (yourself for small ones, `orchestra delegate` for larger ones).
