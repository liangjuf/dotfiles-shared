#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: create_feature_worktree.sh <task-slug-or-branch> [base-ref]

Creates a git worktree for feature development.
- Branch names are always lfeng/<task-slug>.
- Uses .worktrees/<task-slug> when repo-local .worktrees exists or is ignored.
- Falls back to a sibling path named <repo-name>-<task-slug>.
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage >&2
    exit 2
fi

input="$1"
base_ref="${2:-}"

repo_root="$(git rev-parse --show-toplevel)"
repo_name="$(basename "$repo_root")"
repo_parent="$(dirname "$repo_root")"

slug="${input#lfeng/}"
slug="$(printf '%s' "$slug" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"

if [ -z "$slug" ]; then
    echo "error: task slug is empty after normalization" >&2
    exit 2
fi

branch="lfeng/$slug"

cd "$repo_root"

if [ -n "$(git status --porcelain)" ]; then
    echo "note: current checkout has uncommitted changes; leaving them untouched" >&2
fi

if git remote get-url origin >/dev/null 2>&1; then
    git fetch origin
fi

if [ -z "$base_ref" ]; then
    if git show-ref --verify --quiet refs/remotes/origin/main; then
        base_ref="origin/main"
    elif git show-ref --verify --quiet refs/remotes/origin/master; then
        base_ref="origin/master"
    else
        base_ref="$(git branch --show-current || true)"
        if [ -z "$base_ref" ]; then
            base_ref="HEAD"
        fi
    fi
fi

existing_worktree="$(git worktree list --porcelain | awk -v target="refs/heads/$branch" '
    /^worktree / {
        path = $0
        sub(/^worktree /, "", path)
    }
    /^branch / {
        branch = $0
        sub(/^branch /, "", branch)
        if (branch == target) {
            print path
            exit
        }
    }
')"

if [ -n "$existing_worktree" ]; then
    echo "worktree: $existing_worktree"
    echo "branch: $branch"
    echo "base: already exists"
    exit 0
fi

if [ -d "$repo_root/.worktrees" ] || git check-ignore -q .worktrees/probe 2>/dev/null; then
    worktree_path="$repo_root/.worktrees/$slug"
else
    worktree_path="$repo_parent/$repo_name-$slug"
fi

if [ -e "$worktree_path" ]; then
    echo "error: worktree path already exists: $worktree_path" >&2
    exit 1
fi

if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$worktree_path" "$branch"
elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git worktree add -b "$branch" "$worktree_path" "origin/$branch"
else
    git worktree add -b "$branch" "$worktree_path" "$base_ref"
fi

echo "worktree: $worktree_path"
echo "branch: $branch"
echo "base: $base_ref"
