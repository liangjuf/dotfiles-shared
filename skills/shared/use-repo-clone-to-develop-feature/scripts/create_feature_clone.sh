#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: create_feature_clone.sh <task-slug-or-branch> [base-ref]

Creates a separate repo clone for feature development.
- Branch names are always lfeng/<task-slug>.
- Uses a sibling path named <repo-name>-<task-slug>.
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
clone_path="$repo_parent/$repo_name-$slug"

cd "$repo_root"

if [ -n "$(git status --porcelain)" ]; then
    echo "note: current checkout has uncommitted changes; leaving them untouched" >&2
fi

origin_url="$(git remote get-url origin 2>/dev/null || true)"
if [ -z "$origin_url" ]; then
    echo "error: current repo has no origin remote to clone" >&2
    exit 1
fi

git fetch origin

if [ -e "$clone_path" ]; then
    if [ -d "$clone_path/.git" ]; then
        existing_branch="$(git -C "$clone_path" branch --show-current || true)"
        if [ "$existing_branch" = "$branch" ]; then
            echo "clone: $clone_path"
            echo "branch: $branch"
            echo "base: already exists"
            exit 0
        fi
    fi

    echo "error: clone path already exists for a different checkout: $clone_path" >&2
    exit 1
fi

git clone "$origin_url" "$clone_path"
cd "$clone_path"
git fetch origin

if [ -z "$base_ref" ]; then
    if git show-ref --verify --quiet refs/remotes/origin/main; then
        base_ref="origin/main"
    elif git show-ref --verify --quiet refs/remotes/origin/master; then
        base_ref="origin/master"
    else
        remote_head="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
        if [ -n "$remote_head" ]; then
            base_ref="$remote_head"
        else
            base_ref="$(git branch --show-current || true)"
            if [ -z "$base_ref" ]; then
                base_ref="HEAD"
            fi
        fi
    fi
fi

if ! git rev-parse --verify --quiet "$base_ref^{commit}" >/dev/null; then
    if git rev-parse --verify --quiet "origin/$base_ref^{commit}" >/dev/null; then
        base_ref="origin/$base_ref"
    else
        echo "error: base ref not found in clone: $base_ref" >&2
        exit 1
    fi
fi

if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git checkout -b "$branch" "origin/$branch"
elif git show-ref --verify --quiet "refs/heads/$branch"; then
    git checkout "$branch"
else
    git checkout --no-track -b "$branch" "$base_ref"
fi

echo "clone: $clone_path"
echo "branch: $branch"
echo "base: $base_ref"
