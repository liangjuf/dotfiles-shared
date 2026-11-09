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
