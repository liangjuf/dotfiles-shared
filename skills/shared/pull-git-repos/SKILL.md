---
name: pull-git-repos
description: Pull or update every clean git repository and linked worktree under one or more roots, with optional cleanup for merged PR worktrees and local branches. Use when the user asks to pull all repos, update all git checkouts, sync worktrees, remove merged worktrees, clean merged branches, refresh local branches, or run a machine-wide git pull sweep.
---

# Pull Git Repos

## Core Rule

Use the bundled script to update many repositories. Do not hand-roll a one-off
`find ... git pull` command.

## Workflow

1. Choose the search root. If the user does not specify one, use `$HOME`.
2. Run a dry run first:

```bash
bash <skill-dir>/scripts/pull_all_git_repos.sh --dry-run --cleanup-merged-worktrees --cleanup-merged-branches --root "$HOME"
```

3. If the dry run target set is reasonable, run the pull:

```bash
bash <skill-dir>/scripts/pull_all_git_repos.sh --cleanup-merged-worktrees --cleanup-merged-branches --root "$HOME"
```

4. Report the counts for updated, skipped, and failed repositories. Mention any
   removed worktrees, skipped repos, and failures that need manual attention.

## Safety Defaults

- The script discovers normal git working trees and linked worktrees.
- It skips dirty worktrees, detached HEADs, repos without an upstream, and repos
  with in-progress merge/rebase/cherry-pick/revert operations.
- With `--cleanup-merged-worktrees`, it removes only clean linked worktrees whose
  current branch has a GitHub PR with state `MERGED` or is already merged into
  the default branch.
- With `--cleanup-merged-branches`, it deletes only local branches whose GitHub
  PR has state `MERGED` or whose branch is already merged into the default
  branch; it never deletes remote branches.
- It skips protected branch names: `main`, `master`, `trunk`, `develop`, and
  `development`.
- It skips checked-out branches unless their linked worktree was just removed.
- It pulls with `--ff-only` so diverged branches fail instead of creating merge
  commits.
- Use `--allow-dirty` only when the user explicitly accepts the risk.

## Useful Options

- `--root PATH`: scan a root. Can be repeated.
- `--dry-run`: print what would be pulled without running `git pull`.
- `--jobs N`: pull up to N repos in parallel. Default is 1.
- `--allow-dirty`: do not skip dirty worktrees.
- `--no-prune`: skip `git pull --prune`.
- `--cleanup-merged-worktrees`: remove clean linked worktrees after confirming
  the branch's GitHub PR is merged or the branch is locally merged into the
  default branch.
- `--cleanup-merged-branches`: delete local branches after confirming the
  branch's GitHub PR is merged or the branch is locally merged into the default
  branch.
