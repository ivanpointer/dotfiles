# Open Brain Memory Protocol

Before starting any non-trivial task, check Open Brain for relevant context when the Open Brain MCP tools are available.

- Use `search_thoughts` or `search` with a concise query covering the project, repo, tool, person, or decision involved.
- Treat Open Brain results as context, not absolute truth. Prefer explicit user instructions, current repository files, and live tool output when they conflict.
- Do not rely on memory for facts that are easy and important to verify from the current workspace.
- If Open Brain tools are unavailable, continue the task and mention that no Open Brain recall occurred when it matters.

At the end of meaningful work, consider writing compact operational memory with `capture_thought` when the session produced durable decisions, user preferences, reusable repo lessons, unresolved blockers, or concrete next steps.

- Search first to avoid obvious duplicate captures.
- Capture only self-contained summaries with provenance such as repo, file, date, task, or session context.
- Do not capture secrets, credentials, raw logs, large code blocks, private customer data, PHI, or low-value transcript noise.

## Audible Completion Alerts

The user multitasks across several agent sessions and needs to know when one needs attention. **Every turn must end with a spoken summary.** Before you finish responding -- whether the work is finished, blocked, or waiting on the user's input -- call `say` yourself with a short summary of what you did and what, if anything, you need. Nothing does this for you automatically, and a turn that ends without a `say` call is incomplete.

Keep it to a sentence or two, and lead with the repo or task name so the user can tell which session spoke -- e.g. `say "dotfiles: comment conventions applied to all four harness files, nothing left to do"` or `say "dotfiles: need input on which harnesses count"`. Decide the wording yourself each time; a contentless ping like "done" does not satisfy this.

**Only the top-level agent speaks.** If you were spawned as a subagent/child task by another agent, do not call `say` -- only the agent talking directly to the user should.
