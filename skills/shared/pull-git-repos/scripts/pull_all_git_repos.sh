#!/usr/bin/env bash
set -u

usage() {
    cat <<'USAGE'
Usage: pull_all_git_repos.sh [--root PATH ...] [--dry-run] [--jobs N] [--allow-dirty] [--no-prune] [--cleanup-merged-worktrees] [--cleanup-merged-branches]

Find git working trees under the selected roots, add their linked worktrees,
and pull clean branches with upstreams using git pull --ff-only.

Options:
  --root PATH                  Root directory to scan. Repeatable. Defaults to $HOME.
  --dry-run                    Print planned actions without mutating repositories.
  --jobs N                     Pull up to N repositories at a time. Defaults to 1.
  --allow-dirty                Pull dirty worktrees too. Use only when explicitly intended.
  --no-prune                   Do not pass --prune to git pull.
  --cleanup-merged-worktrees   Remove clean linked worktrees whose GitHub PR is merged or whose branch is merged into the default branch.
  --cleanup-merged-branches    Delete local branches whose GitHub PR is merged or whose branch is merged into the default branch.
  -h, --help                   Show this help.
USAGE
}

roots=()
dry_run=0
jobs=1
allow_dirty=0
prune=1
cleanup_merged_worktrees=0
cleanup_merged_branches=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)
            if [ "$#" -lt 2 ]; then
                echo "error: --root requires a path" >&2
                exit 2
            fi
            roots+=("$2")
            shift 2
            ;;
        --dry-run)
            dry_run=1
            shift
            ;;
        --jobs)
            if [ "$#" -lt 2 ] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
                echo "error: --jobs requires a positive integer" >&2
                exit 2
            fi
            jobs="$2"
            shift 2
            ;;
        --allow-dirty)
            allow_dirty=1
            shift
            ;;
        --no-prune)
            prune=0
            shift
            ;;
        --cleanup-merged-worktrees)
            cleanup_merged_worktrees=1
            shift
            ;;
        --cleanup-merged-branches)
            cleanup_merged_branches=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ "${#roots[@]}" -eq 0 ]; then
    roots=("${HOME:?HOME is not set}")
fi

if ! command -v git >/dev/null 2>&1; then
    echo "error: git is not available" >&2
    exit 127
fi

if { [ "$cleanup_merged_worktrees" -eq 1 ] || [ "$cleanup_merged_branches" -eq 1 ]; } && [ "$jobs" -ne 1 ]; then
    echo "note: cleanup modes run serially; forcing --jobs 1" >&2
    jobs=1
fi

declare -A seen=()
declare -A would_remove_worktree_branch=()
repos=()

add_repo() {
    local candidate="$1"
    local top

    if ! top="$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null)"; then
        return 0
    fi
    top="$(realpath "$top" 2>/dev/null || printf '%s\n' "$top")"
    if [ -z "${seen[$top]+x}" ]; then
        seen["$top"]=1
        repos+=("$top")
    fi
}

discover_root() {
    local root="$1"
    if [ ! -d "$root" ]; then
        echo "skip root (not a directory): $root" >&2
        return 0
    fi

    while IFS= read -r git_marker; do
        case "$git_marker" in
            */.git/modules/*) continue ;;
        esac
        add_repo "$(dirname "$git_marker")"
    done < <(
        find "$root" \
            \( -type d \( -name .cache -o -name node_modules -o -name .venv -o -name __pycache__ \) -prune \) \
            -o \( -name .git -type d -print -prune \) \
            -o \( -name .git -type f -print \) 2>/dev/null
    )
}

add_linked_worktrees() {
    local existing=("${repos[@]}")
    local repo worktree

    for repo in "${existing[@]}"; do
        while IFS= read -r worktree; do
            [ -n "$worktree" ] || continue
            [ -d "$worktree" ] || continue
            add_repo "$worktree"
        done < <(git -C "$repo" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
    done
}

is_operation_in_progress() {
    local repo="$1"
    local git_dir

    git_dir="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null)" || return 0
    [ -e "$git_dir/MERGE_HEAD" ] && return 0
    [ -e "$git_dir/CHERRY_PICK_HEAD" ] && return 0
    [ -e "$git_dir/REVERT_HEAD" ] && return 0
    [ -d "$git_dir/rebase-apply" ] && return 0
    [ -d "$git_dir/rebase-merge" ] && return 0
    return 1
}

primary_worktree() {
    local repo="$1"
    git -C "$repo" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p'
}

is_linked_worktree() {
    local repo="$1"
    local primary repo_real primary_real

    primary="$(primary_worktree "$repo")"
    [ -n "$primary" ] || return 1
    repo_real="$(realpath "$repo" 2>/dev/null || printf '%s\n' "$repo")"
    primary_real="$(realpath "$primary" 2>/dev/null || printf '%s\n' "$primary")"
    [ "$repo_real" != "$primary_real" ]
}

merged_pr_info() {
    local repo="$1"
    local branch="$2"

    if ! command -v gh >/dev/null 2>&1; then
        return 1
    fi

    (
        cd "$repo" &&
            gh pr view "$branch" \
                --json number,state,mergedAt,url,title \
                --template '{{if eq .state "MERGED"}}#{{.number}} {{.url}} merged {{.mergedAt}} {{.title}}{{end}}'
    ) 2>/dev/null
}

is_protected_branch() {
    case "$1" in
        main|master|trunk|develop|development)
            return 0
            ;;
    esac
    return 1
}

default_branch_ref() {
    local repo="$1"
    local ref

    ref="$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    if [ -n "$ref" ] && git -C "$repo" rev-parse --verify --quiet "$ref^{commit}" >/dev/null; then
        printf '%s\n' "$ref"
        return 0
    fi

    for ref in origin/main origin/master; do
        if git -C "$repo" rev-parse --verify --quiet "$ref^{commit}" >/dev/null; then
            printf '%s\n' "$ref"
            return 0
        fi
    done

    return 1
}

locally_merged_info() {
    local repo="$1"
    local branch="$2"
    local target

    is_protected_branch "$branch" && return 1
    target="$(default_branch_ref "$repo")" || return 1
    git -C "$repo" merge-base --is-ancestor "$branch" "$target" 2>/dev/null || return 1
    printf 'locally merged into %s' "$target"
}

merged_cleanup_info() {
    local repo="$1"
    local branch="$2"
    local info

    info="$(merged_pr_info "$repo" "$branch")"
    if [ -n "$info" ]; then
        printf '%s\n' "$info"
        return 0
    fi

    locally_merged_info "$repo" "$branch"
}

cleanup_merged_worktree() {
    local repo="$1"
    local branch="$2"
    local primary cleanup_info

    [ "$cleanup_merged_worktrees" -eq 1 ] || return 1
    is_linked_worktree "$repo" || return 1

    cleanup_info="$(merged_cleanup_info "$repo" "$branch")"
    [ -n "$cleanup_info" ] || return 1

    if [ "$dry_run" -eq 1 ]; then
        echo "WOULD remove merged worktree: $repo [$branch, $cleanup_info]"
        if [ "$cleanup_merged_branches" -eq 1 ]; then
            primary="$(primary_worktree "$repo")"
            primary="$(realpath "$primary" 2>/dev/null || printf '%s\n' "$primary")"
            echo "WOULD delete merged branch after worktree removal: $primary [$branch, $cleanup_info]"
            would_remove_worktree_branch["$primary|$branch"]=1
            branches_cleaned=$((branches_cleaned + 1))
        fi
        return 30
    fi

    primary="$(primary_worktree "$repo")"
    if git -C "$primary" worktree remove "$repo"; then
        echo "OK removed merged worktree: $repo [$branch, $cleanup_info]"
        return 30
    fi

    echo "FAIL remove merged worktree: $repo [$branch, $cleanup_info]" >&2
    return 2
}

is_branch_checked_out() {
    local repo="$1"
    local branch="$2"

    git -C "$repo" worktree list --porcelain 2>/dev/null | grep -Fxq "branch refs/heads/$branch"
}

cleanup_merged_branches_in_repo() {
    local repo="$1"
    local branch cleanup_info

    [ "$cleanup_merged_branches" -eq 1 ] || return 0
    [ -d "$repo" ] || return 0

    if is_operation_in_progress "$repo"; then
        echo "SKIP branch cleanup in-progress: $repo"
        branches_skipped=$((branches_skipped + 1))
        return 0
    fi

    while IFS= read -r branch; do
        [ -n "$branch" ] || continue
        is_protected_branch "$branch" && continue

        cleanup_info="$(merged_cleanup_info "$repo" "$branch")"
        [ -n "$cleanup_info" ] || continue

        if [ "$dry_run" -eq 1 ] && [ -n "${would_remove_worktree_branch["$repo|$branch"]+x}" ]; then
            continue
        fi

        if is_branch_checked_out "$repo" "$branch"; then
            echo "SKIP merged branch checked out: $repo [$branch, $cleanup_info]"
            branches_skipped=$((branches_skipped + 1))
            continue
        fi

        if [ "$dry_run" -eq 1 ]; then
            echo "WOULD delete merged branch: $repo [$branch, $cleanup_info]"
            branches_cleaned=$((branches_cleaned + 1))
            continue
        fi

        if git -C "$repo" branch -D "$branch" >/dev/null; then
            echo "OK deleted merged branch: $repo [$branch, $cleanup_info]"
            branches_cleaned=$((branches_cleaned + 1))
        else
            echo "FAIL delete merged branch: $repo [$branch, $cleanup_info]" >&2
            branches_failed=$((branches_failed + 1))
        fi
    done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)
}

pull_repo() {
    local repo="$1"
    local branch upstream pull_args cleanup_status

    if is_operation_in_progress "$repo"; then
        echo "SKIP in-progress: $repo"
        return 20
    fi

    branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
    if [ -z "$branch" ]; then
        echo "SKIP detached: $repo"
        return 21
    fi

    if [ "$allow_dirty" -eq 0 ] && [ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]; then
        echo "SKIP dirty: $repo [$branch]"
        return 23
    fi

    cleanup_merged_worktree "$repo" "$branch"
    cleanup_status=$?
    if [ "$cleanup_status" -eq 30 ]; then
        return 30
    elif [ "$cleanup_status" -ne 1 ]; then
        return "$cleanup_status"
    fi

    upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [ -z "$upstream" ]; then
        echo "SKIP no-upstream: $repo [$branch]"
        return 22
    fi

    if [ "$dry_run" -eq 1 ]; then
        echo "WOULD pull: $repo [$branch -> $upstream]"
        return 0
    fi

    pull_args=(pull --ff-only)
    if [ "$prune" -eq 1 ]; then
        pull_args+=(--prune)
    fi

    if git -C "$repo" "${pull_args[@]}"; then
        echo "OK pulled: $repo [$branch -> $upstream]"
        return 0
    fi

    echo "FAIL pull: $repo [$branch -> $upstream]" >&2
    return 1
}

run_one() {
    local repo="$1"
    pull_repo "$repo"
}

for root in "${roots[@]}"; do
    discover_root "$root"
done
add_linked_worktrees

if [ "${#repos[@]}" -gt 0 ]; then
    mapfile -t repos < <(printf '%s\n' "${repos[@]}" | sort)
fi

declare -A seen_primaries=()
primaries=()
for repo in "${repos[@]}"; do
    primary="$(primary_worktree "$repo")"
    [ -n "$primary" ] || continue
    primary="$(realpath "$primary" 2>/dev/null || printf '%s\n' "$primary")"
    if [ -z "${seen_primaries[$primary]+x}" ]; then
        seen_primaries["$primary"]=1
        primaries+=("$primary")
    fi
done

echo "Found ${#repos[@]} git working tree(s)."

ok=0
skipped=0
worktrees_cleaned=0
branches_cleaned=0
branches_skipped=0
branches_failed=0
failed=0

if [ "$jobs" -eq 1 ]; then
    for repo in "${repos[@]}"; do
        run_one "$repo"
        status=$?
        if [ "$status" -eq 0 ]; then
            ok=$((ok + 1))
        elif [ "$status" -ge 20 ] && [ "$status" -lt 30 ]; then
            skipped=$((skipped + 1))
        elif [ "$status" -ge 30 ] && [ "$status" -lt 40 ]; then
            worktrees_cleaned=$((worktrees_cleaned + 1))
        else
            failed=$((failed + 1))
        fi
    done
else
    tmp_status="$(mktemp)"
    for repo in "${repos[@]}"; do
        (
            run_one "$repo"
            printf '%s\n' "$?" >> "$tmp_status"
        ) &

        while [ "$(jobs -rp | wc -l)" -ge "$jobs" ]; do
            sleep 0.2
        done
    done
    wait

    while IFS= read -r status; do
        if [ "$status" -eq 0 ]; then
            ok=$((ok + 1))
        elif [ "$status" -ge 20 ] && [ "$status" -lt 30 ]; then
            skipped=$((skipped + 1))
        elif [ "$status" -ge 30 ] && [ "$status" -lt 40 ]; then
            worktrees_cleaned=$((worktrees_cleaned + 1))
        else
            failed=$((failed + 1))
        fi
    done < "$tmp_status"
    rm -f "$tmp_status"
fi

if [ "$cleanup_merged_branches" -eq 1 ]; then
    for primary in "${primaries[@]}"; do
        cleanup_merged_branches_in_repo "$primary"
    done
fi

echo "Summary: ok=$ok skipped=$skipped worktrees_cleaned=$worktrees_cleaned branches_cleaned=$branches_cleaned branches_skipped=$branches_skipped failed=$((failed + branches_failed))"

if [ "$((failed + branches_failed))" -gt 0 ]; then
    exit 1
fi
