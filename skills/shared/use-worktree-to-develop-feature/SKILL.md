---
name: use-worktree-to-develop-feature
description: Create and use isolated git worktrees for feature development. Use when starting feature work, non-trivial refactors, PR-bound changes, creating a new feature branch, or when the user asks to use a git worktree. Enforces feature branch names in the form lfeng/task-slug.
---

# Use Worktree to Develop Feature

## Core Rule

Do feature development in a dedicated git worktree, not in the main checkout.

## Required Workflow

1. Inspect the current checkout with `git status --short`, `git branch --show-current`, and `git remote -v`.
2. Leave unrelated dirty files in the main checkout untouched.
3. Pick the base ref from the user request. If none is given, prefer `origin/main`, then `origin/master`, then the current branch.
4. Create a task slug and branch named `lfeng/<task-slug>`.
5. Create or reuse a dedicated worktree before editing.
6. Run implementation, tests, commits, and PR commands from inside the worktree.
7. Report the worktree path, branch name, changed files, and verification results.

## Helper Script

Use `scripts/create_feature_worktree.sh` from this skill when creating a new worktree:

```bash
bash <skill-dir>/scripts/create_feature_worktree.sh <task-slug> [base-ref]
```

The script normalizes the branch to `lfeng/<task-slug>`, fetches `origin` when available, and chooses the worktree path:

- `.worktrees/<task-slug>` when repo-local `.worktrees` already exists or is ignored
- a sibling directory named `<repo>-<task-slug>` otherwise

## Manual Fallback

If the script cannot be used:

```bash
git fetch origin
git worktree add .worktrees/<task-slug> -b lfeng/<task-slug> origin/<base-branch>
cd .worktrees/<task-slug>
```

Use an external path instead of `.worktrees/<task-slug>` when `.worktrees` is not ignored or already established in the repo.

## Cleanup

After merge or abandonment, remove only the worktree and local task branch that this workflow created:

```bash
git worktree remove <worktree-path>
git branch -d lfeng/<task-slug>
```

Never delete a remote branch unless the user explicitly asks.

## Red Flags

- Editing feature code in the main checkout after this skill has triggered
- Using a branch that does not start with `lfeng/`
- Reusing a worktree for an unrelated task
- Deleting user changes or unrelated worktrees during cleanup
