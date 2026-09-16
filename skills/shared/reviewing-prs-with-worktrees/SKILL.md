---
name: reviewing-prs-with-worktrees
description: Use when reviewing pull requests or inspecting PR diffs so review work always runs in an isolated git worktree instead of the main workspace.
---

# Reviewing PRs with Worktrees

## Core Rule

Always perform PR review in a dedicated git worktree, not in the main workspace.

## Required Workflow

1. Identify PR number and repository.
2. Create or reuse a review worktree for that PR.
3. Run `gh pr checkout <number>` inside the worktree only.
4. Run review commands (diff, tests, lint) inside the worktree.
5. Leave the main workspace on its original branch.

## Naming Convention

- Branch: `pr-<number>`
- Worktree path: `<repo-root>-pr-<number>` or `<repo-root>/.worktrees/pr-<number>`

Reuse an existing matching worktree when present.

## Cleanup

After review is complete (unless user asks to keep it):

1. Switch back to the main workspace.
2. Remove the PR worktree.
3. Delete the local review branch if no longer needed.

Never delete or modify remote branches unless explicitly requested.

## Red Flags

- Running `gh pr checkout` in the main workspace
- Mixing review-only changes with ongoing development work
- Leaving stale PR worktrees after review
