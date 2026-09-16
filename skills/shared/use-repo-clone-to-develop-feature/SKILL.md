---
name: use-repo-clone-to-develop-feature
description: Create and use isolated repo clones for feature development. Use when starting feature work, non-trivial refactors, PR-bound changes, creating a new feature branch, or when the user asks to use a separate repo clone instead of a git worktree. Enforces feature branch names in the form lfeng/task-slug.
---

# Use Repo Clone to Develop Feature

## Core Rule

Do feature development in a dedicated repo clone, not in the main checkout.

## Required Workflow

1. Inspect the current checkout with `git status --short`, `git branch --show-current`, and `git remote -v`.
2. Leave unrelated dirty files in the main checkout untouched.
3. Pick the base ref from the user request. If none is given, prefer `origin/main`, then `origin/master`, then the remote default branch, then the current branch.
4. Create a task slug and branch named `lfeng/<task-slug>`.
5. Create or reuse a dedicated clone before editing.
6. Run implementation, tests, commits, and PR commands from inside the clone.
7. Report the clone path, branch name, changed files, and verification results.

## Helper Script

Use `scripts/create_feature_clone.sh` from this skill when creating a new clone:

```bash
bash <skill-dir>/scripts/create_feature_clone.sh <task-slug> [base-ref]
```

The script normalizes the branch to `lfeng/<task-slug>`, fetches `origin`, clones into a sibling directory named `<repo>-<task-slug>`, and reuses that directory only when it is already on the expected branch.

## Manual Fallback

If the script cannot be used:

```bash
git fetch origin
git clone "$(git remote get-url origin)" ../<repo>-<task-slug>
cd ../<repo>-<task-slug>
git checkout -b lfeng/<task-slug> origin/<base-branch>
```

## Cleanup

After merge or abandonment, remove only the clone directory this workflow created:

```bash
rm -rf <clone-path>
```

Never delete a remote branch unless the user explicitly asks.

## Red Flags

- Editing feature code in the main checkout after this skill has triggered
- Using a branch that does not start with `lfeng/`
- Reusing a clone for an unrelated task
- Using `git worktree` for this workflow
- Deleting user changes or unrelated clones during cleanup
