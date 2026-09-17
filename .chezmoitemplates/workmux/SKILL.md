---
name: workmux
description: Coordinate parallel coding work with Workmux worktrees, agent handoffs, status, review, and safe integration. Use when dispatching or managing concurrent coding agents; not for ordinary single-branch Git work.
---

# Workmux coordination

Use Workmux to isolate independently reviewable work, not to bypass Git review
or authorization. Check the installed `workmux <command> --help` when a flag or
behavior is version-sensitive.

## Start from a known baseline

Before dispatching, inspect the current repository and record the intended base
commit. Start with non-Git-mutating inspection: `git status --short`, `git
status -sb`, `git log -1 --oneline`, `workmux list`, and `workmux status --git`.
Workmux observation commands may write their own logs/cache, so do not describe
them as filesystem-pure checks.

- Teams must branch from a clean, committed baseline that is pushed when other
  machines or harnesses must consume it. A worktree is fixed at creation; later
  commits on its base do **not** appear automatically.
- A dirty current worktree is not necessarily a dirty base. Leave its changes
  untouched and pin every team to a verified pushed commit when that meets the
  user's goal. Otherwise, commit/push or explicitly move the changes. Never
  silently branch from or distribute a dirty state.
- `workmux add --dry-run` is a useful read-only plan check. `workmux add`
  creates Git worktrees/branches, runs configured hooks/file operations, and
  may create tmux targets; treat it as a mutation requiring normal task
  authorization.

## Dispatch deliberately

Split only independent work. Give one team ownership of each shared contract,
schema, or high-conflict file; have that team publish its committed interface
before dependent teams integrate.

Every prompt should identify the work item, exact base commit, owned paths,
expected behavior, required tests and their prerequisites, prohibited scope,
and handoff format: commit(s), commands actually run with results, and known
limits. Do not ask agents to infer a broad shared diff.

For work scheduled later, persist the prompts and recorded base plan but do not
pre-create stale worktrees. At dispatch time, revalidate the repository and
repin the base; scheduling agents or commands outside Workmux needs separate
authorization.

Use `workmux status --git`, `workmux capture <handle>`, and `workmux path
<handle>` to monitor. Use `workmux send <handle> ...` only to give a scoped
follow-up; it changes an active agent's instructions. Status or terminal text
is not proof that a test passed—report absent entrypoints, dependencies, or
environment failures exactly as observed. Keep proposed architecture separate
from a tested implementation or deployed service.

For detailed command patterns—including safe handling of uncommitted and
untracked files—read [operations](references/operations.md).

## Integrate only after review

Review each team's scoped commit/diff and independently run the agreed checks.
Rebase worktrees deliberately if their base advanced; resolve conflicts with
the owning team when they affect its contract. Do not merge merely because an
agent is done.

`workmux rebase`, `workmux merge`, `workmux remove`, and force/ignore flags
mutate history, branches, worktrees, or tmux state. `merge` normally cleans up
the branch and worktree. Use them only with explicit authorization after review
and verification; never use `--force`, `--ignore-uncommitted`, `--no-verify`,
or bulk removal as routine cleanup.
