#!/usr/bin/env bash
# --no-pull --cleanup-merged-worktrees --min-idle-hours removes merged linked
# worktrees that have been idle long enough, keeps recently active ones, and
# never pulls. Uses the local-merge path: a stub gh that fails keeps the GitHub
# PR lookup out of the way.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/skills/shared/pull-git-repos/scripts/pull_all_git_repos.sh"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
# The script realpaths discovered repos; match that on macOS (/var -> /private/var).
fixture="$(realpath "$fixture")"

fail() { echo "ERROR: $*" >&2; exit 1; }

export GIT_AUTHOR_NAME="Test User" GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Test User" GIT_COMMITTER_EMAIL="test@example.com"

# Stub gh so the merged-PR lookup fails and the local-merge path is used.
mkdir -p "$fixture/bin"
printf '#!/usr/bin/env bash\nexit 1\n' > "$fixture/bin/gh"
chmod +x "$fixture/bin/gh"
export PATH="$fixture/bin:$PATH"

origin="$fixture/origin.git"
git init -q --bare --initial-branch=main "$origin"

# Seeder clone: owns main on origin and later pushes a commit on top.
seeder="$fixture/seeder"
git clone -q "$origin" "$seeder"
git -C "$seeder" checkout -q -b main
echo one > "$seeder/file.txt"
git -C "$seeder" add file.txt
git -C "$seeder" commit -qm 'initial'
git -C "$seeder" push -q -u origin main

# Primary clone with two feature branches, both merged into main and pushed.
primary="$fixture/primary"
git clone -q "$origin" "$primary"
for name in old-wt fresh-wt; do
    git -C "$primary" checkout -q -b "$name"
    echo "$name" > "$primary/$name.txt"
    git -C "$primary" add "$name.txt"
    git -C "$primary" commit -qm "add $name"
done
git -C "$primary" checkout -q main
git -C "$primary" merge -q --no-ff old-wt -m 'merge old-wt'
git -C "$primary" merge -q --no-ff fresh-wt -m 'merge fresh-wt'
git -C "$primary" push -q origin main

old_wt="$fixture/old"
fresh_wt="$fixture/fresh"
git -C "$primary" worktree add -q "$old_wt" old-wt
git -C "$primary" worktree add -q "$fresh_wt" fresh-wt

# One worktree is long idle; the other was just touched.
find "$old_wt" -exec touch -t 202001010000 {} +

# Advance origin/main from the seeder so a pull would move the primary's main.
git -C "$seeder" pull -q
echo two > "$seeder/file.txt"
git -C "$seeder" add file.txt
git -C "$seeder" commit -qm 'second'
git -C "$seeder" push -q origin main

main_before="$(git -C "$primary" rev-parse main)"

# Dry run reports both decisions and removes nothing.
dry_out="$(bash "$SCRIPT" --root "$fixture" --dry-run --cleanup-merged-worktrees --min-idle-hours 24)"
grep -Fq "WOULD remove merged worktree: $old_wt [old-wt," <<<"$dry_out" \
    || fail "dry run did not plan to remove the idle worktree: $dry_out"
grep -Fq "SKIP recently active worktree: $fresh_wt [fresh-wt," <<<"$dry_out" \
    || fail "dry run did not skip the fresh worktree: $dry_out"
[ -d "$old_wt" ] || fail "dry run removed the idle worktree"
[ -d "$fresh_wt" ] || fail "dry run removed the fresh worktree"
echo "PASS: dry run plans removal of idle worktree and skips the active one"

# Real run with --no-pull: removes the idle worktree, keeps the active one.
out="$(bash "$SCRIPT" --root "$fixture" --no-pull --cleanup-merged-worktrees --min-idle-hours 24)"
grep -Fq "OK removed merged worktree: $old_wt [old-wt," <<<"$out" \
    || fail "did not remove the idle worktree: $out"
grep -Fq "SKIP recently active worktree: $fresh_wt [fresh-wt," <<<"$out" \
    || fail "did not skip the fresh worktree: $out"
[ ! -d "$old_wt" ] || fail "idle worktree still exists"
[ -d "$fresh_wt" ] || fail "fresh worktree was removed"
echo "PASS: --no-pull removes idle merged worktree and keeps the active one"

# --no-pull must not pull: the primary's main did not move even though origin/main advanced.
main_after="$(git -C "$primary" rev-parse main)"
[ "$main_before" = "$main_after" ] || fail "--no-pull moved main: $main_before -> $main_after"
grep -Fq 'Summary: ' <<<"$out" || fail "missing summary: $out"
echo "PASS: --no-pull leaves the primary checkout untouched"
