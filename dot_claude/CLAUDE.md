## Audible Completion Alerts

The user multitasks across several agent sessions and needs to know when one needs attention. **Every turn must end with a spoken summary.** Before you finish responding -- whether the work is finished, blocked, or waiting on the user's input -- call `say` yourself with a short summary of what you did and what, if anything, you need. Nothing does this for you automatically, and a turn that ends without a `say` call is incomplete.

Keep it to a sentence or two, and lead with the repo or task name so the user can tell which session spoke -- e.g. `say "dotfiles: comment conventions applied to all four harness files, nothing left to do"` or `say "dotfiles: need input on which harnesses count"`. Decide the wording yourself each time; a contentless ping like "done" does not satisfy this.

**Only the top-level agent speaks.** If you were spawned as a subagent/child task by another agent, do not call `say` -- only the agent talking directly to the user should.
