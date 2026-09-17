# Workmux operating patterns

Run commands from the target repository unless using an explicit cross-project
`project:handle` reference. Handles are Workmux worktree names, not arbitrary
branch guesses.

## Read-only preflight

```sh
git status --short
git status -sb
git log -1 --oneline
workmux list
workmux status --git
workmux add team-topic --base <recorded-base> --dry-run
```

If the current branch has an upstream, compare it before dispatching:

```sh
git log --oneline '@{upstream}..HEAD'
git log --oneline 'HEAD..@{upstream}'
```

`git fetch` updates local refs, so treat it as a normal authorized network/state
operation rather than a read-only inspection. After it is authorized, verify
the intended main/upstream relationship and record the full `git rev-parse
origin/main` SHA (or the explicitly chosen pushed ref). Use that same SHA in
every `--base` invocation and every team prompt.

## Creation and handoff

Use a prompt file for substantial work so quoting does not change its meaning:

```sh
workmux add phase3-gateway --base <base-commit> --background --prompt-file <prompt-file>
```

This creates a branch/worktree, runs configured setup, and creates a tmux
target; do it only when the user authorized delegation. `--headless --json` is
useful for noninteractive provisioning but still creates a worktree and runs
applicable setup. `--parent-session` controls tmux placement; it does not
change the repository selected by the command's working directory.

A useful handoff has these fields:

```text
Work item and base: <objective>; branch from <full commit>
Ownership: <paths/contracts>; do not edit <shared/conflicting paths>
Behavior and evidence: <acceptance checks>; run <commands> when prerequisites exist
Boundaries: <security/product non-goals>
Handoff: commit changes; report exact tests/results, failures, and limitations
```

After a main/base branch changes, existing team worktrees remain on their old
commit. Rebase or selectively integrate only after reviewing the base change;
do not claim they are current because they share a repository.

For work planned for a later time, save the prompt files and intended baseline
but do not create worktrees early. Re-run preflight, authorize any fetch, and
record a fresh common SHA immediately before dispatching. Workmux does not
schedule future agent starts by itself.

## Moving unfinished work

`workmux add --with-changes` moves staged and modified tracked files from the
current worktree and resets that source state. Add `--patch` to choose hunks.
`--include-untracked` also moves untracked files. These are intentional moves,
not a way to seed multiple teams or preserve a dirty baseline.

Before either flag, inspect `git status --short`, identify every affected path,
ensure no active team owns it, and get explicit permission to move it. Prefer a
clean commit and explicit `--base` for parallel work. Never use
`--include-untracked` by default: untracked files can contain local fixtures,
credentials, generated output, or unrelated work.

## Coordination and evidence

```sh
workmux status --git
workmux capture phase3-gateway -n 100
workmux send phase3-gateway "Please report the exact failing command and prerequisite."
workmux wait phase3-gateway phase3-runtime --timeout 1800
workmux path phase3-gateway
```

`status`, `capture`, `list`, and `path` inspect state. `send` changes an
agent's assignment. `run` is only as safe as the command supplied; commands
that build, test, migrate, or edit state need their usual authorization even
when launched through Workmux.

An agent's completion is a handoff for review, not a merge signal. Distinguish:

- **implemented and tested**: exact command, exit result, fixture/environment;
- **blocked**: exact missing entrypoint, dependency, credential, or setup;
- **proposed**: design or spike conclusion without production deployment proof.

## Review, rebase, merge, and cleanup

Before integration, inspect the branch against the recorded base, review only
the assigned surface plus contract interactions, and run the agreed checks.
Obtain the actual branch from the team's worktree rather than guessing it:

```sh
team_path="$(workmux path phase3-gateway)"
team_branch="$(git -C "$team_path" branch --show-current)"
git log --oneline "<recorded-base>..$team_branch"
git diff --stat "<recorded-base>...$team_branch"
```

When the base advanced, `workmux rebase <handle>` rewrites that worktree's
branch; authorize it and preserve conflict evidence if it fails.

`workmux merge <handle>` changes the target branch and, unless kept, removes the
worktree, tmux target, and branch. `workmux remove <handle>` removes without
merging. Do not use `--force`, `--all`, `--ignore-uncommitted`, `--no-verify`,
or `--no-hooks` merely to make cleanup succeed. Confirm the exact target,
review state, test result, and recoverability first. Keep the worktree when a
post-merge investigation or comparison is still needed. Merge one reviewed team
at a time; after each merge, record the new base and review/rebase every
remaining team before its own integration.
