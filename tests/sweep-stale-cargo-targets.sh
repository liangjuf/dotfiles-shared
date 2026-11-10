#!/usr/bin/env bash
# Only a directory named "target" with a CACHEDIR.TAG marker is a cargo target,
# and only stale ones are removed: the dry run must list exactly the old tagged
# one and a real run must remove exactly that one. A stale target whose parent
# directory is a process's cwd is reported in use and kept.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/sweep-stale-cargo-targets.sh"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

fail() { echo "ERROR: $*" >&2; exit 1; }

# Old cargo target: marker plus files, everything backdated.
mkdir -p "$fixture/proj-old/target/debug"
echo cached > "$fixture/proj-old/target/CACHEDIR.TAG"
echo artifact > "$fixture/proj-old/target/debug/artifact"
find "$fixture/proj-old" -exec touch -t 202001010000 {} +

# Fresh cargo target: built just now.
mkdir -p "$fixture/proj-fresh/target"
echo cached > "$fixture/proj-fresh/target/CACHEDIR.TAG"
echo artifact > "$fixture/proj-fresh/target/artifact"

# Old directory named target without the marker: never a cargo target.
mkdir -p "$fixture/proj-plain/target"
echo not-cargo > "$fixture/proj-plain/target/file.txt"
find "$fixture/proj-plain" -exec touch -t 202001010000 {} +

# Old tagged target whose parent has a process sitting in it: stale by mtime,
# but in use, so it must be skipped on every OS.
mkdir -p "$fixture/proj-busy/target"
echo cached > "$fixture/proj-busy/target/CACHEDIR.TAG"
find "$fixture/proj-busy" -exec touch -t 202001010000 {} +
(cd "$fixture/proj-busy" && exec sleep 300) &
busy_pid=$!
trap 'kill "$busy_pid" 2>/dev/null; rm -rf "$fixture"' EXIT

dry_out="$(bash "$SCRIPT" --root "$fixture" --days 7 --dry-run)"
grep -Fq "WOULD remove stale cargo target: $fixture/proj-old/target" <<<"$dry_out" \
    || fail "dry run did not list the old cargo target: $dry_out"
grep -Fq "SKIP in use: $fixture/proj-busy/target" <<<"$dry_out" \
    || fail "dry run did not skip the in-use cargo target: $dry_out"
if grep -Fq "proj-fresh" <<<"$dry_out" || grep -Fq "proj-plain" <<<"$dry_out"; then
    fail "dry run listed a target it must not touch: $dry_out"
fi
grep -Eq '^Summary: removed=1 kept=1 skipped=1 failed=0 would_free=' <<<"$dry_out" \
    || fail "unexpected dry run summary: $dry_out"
[ -d "$fixture/proj-old/target" ] || fail "dry run removed the old target"
[ -d "$fixture/proj-busy/target" ] || fail "dry run removed the in-use target"
echo "PASS: dry run lists only the stale tagged target and removes nothing"

out="$(bash "$SCRIPT" --root "$fixture" --days 7)"
grep -Fq "OK removed stale cargo target: $fixture/proj-old/target" <<<"$out" \
    || fail "did not remove the old cargo target: $out"
grep -Fq "SKIP in use: $fixture/proj-busy/target" <<<"$out" \
    || fail "did not skip the in-use cargo target: $out"
grep -Eq '^Summary: removed=1 kept=1 skipped=1 failed=0 freed=' <<<"$out" \
    || fail "unexpected summary: $out"
[ ! -d "$fixture/proj-old/target" ] || fail "old cargo target still exists"
[ -d "$fixture/proj-busy/target" ] || fail "in-use cargo target was removed"
[ -d "$fixture/proj-fresh/target" ] || fail "fresh cargo target was removed"
[ -d "$fixture/proj-plain/target" ] || fail "tagless target was removed"
echo "PASS: real run removes only the stale tagged target"

# --max-size: an oversized target that has been idle for 2+ hours is removed
# even when it is not stale; recent or small targets are kept.
cap_fixture="$(mktemp -d)"
trap 'kill "$busy_pid" 2>/dev/null; rm -rf "$fixture" "$cap_fixture"' EXIT

mkdir -p "$cap_fixture/big-idle/target"
echo cached > "$cap_fixture/big-idle/target/CACHEDIR.TAG"
head -c 262144 /dev/zero > "$cap_fixture/big-idle/target/blob"

mkdir -p "$cap_fixture/big-recent/target"
echo cached > "$cap_fixture/big-recent/target/CACHEDIR.TAG"
head -c 262144 /dev/zero > "$cap_fixture/big-recent/target/blob"

mkdir -p "$cap_fixture/small-idle/target"
echo cached > "$cap_fixture/small-idle/target/CACHEDIR.TAG"
echo tiny > "$cap_fixture/small-idle/target/blob"

ts="$(date -v-3H +%Y%m%d%H%M 2>/dev/null || date -d '3 hours ago' +%Y%m%d%H%M)"
find "$cap_fixture/big-idle" "$cap_fixture/small-idle" -exec touch -t "$ts" {} +

cap_dry_out="$(bash "$SCRIPT" --root "$cap_fixture" --days 7 --max-size 64K --dry-run)"
grep -Fq "WOULD remove oversized cargo target: $cap_fixture/big-idle/target" <<<"$cap_dry_out" \
    || fail "dry run did not list the oversized idle target: $cap_dry_out"
if grep -Fq "big-recent" <<<"$cap_dry_out" || grep -Fq "small-idle" <<<"$cap_dry_out"; then
    fail "dry run listed a target it must not touch: $cap_dry_out"
fi
grep -Eq '^Summary: removed=1 kept=2 skipped=0 failed=0 would_free=' <<<"$cap_dry_out" \
    || fail "unexpected dry run summary: $cap_dry_out"
[ -d "$cap_fixture/big-idle/target" ] || fail "dry run removed the oversized target"
echo "PASS: dry run lists only the oversized idle target and removes nothing"

cap_out="$(bash "$SCRIPT" --root "$cap_fixture" --days 7 --max-size 64K)"
grep -Fq "OK removed oversized cargo target: $cap_fixture/big-idle/target" <<<"$cap_out" \
    || fail "did not remove the oversized idle target: $cap_out"
grep -Eq '^Summary: removed=1 kept=2 skipped=0 failed=0 freed=' <<<"$cap_out" \
    || fail "unexpected summary: $cap_out"
[ ! -d "$cap_fixture/big-idle/target" ] || fail "oversized idle target still exists"
[ -d "$cap_fixture/big-recent/target" ] || fail "recently written target was removed"
[ -d "$cap_fixture/small-idle/target" ] || fail "small idle target was removed"
echo "PASS: real run removes only the oversized idle target"

if bash "$SCRIPT" --root "$cap_fixture" --days 7 --max-size 40 2>/dev/null; then
    fail "--max-size without a unit was accepted"
else
    [ "$?" -eq 2 ] || fail "--max-size without a unit did not exit 2"
fi
echo "PASS: --max-size without a unit exits 2"
