#!/usr/bin/env bash
set -u

usage() {
    cat <<'USAGE'
Usage: sweep-stale-cargo-targets.sh [--root PATH ...] [--days N] [--dry-run]

Delete cargo build output directories (a directory named "target" containing a
CACHEDIR.TAG marker) that have not been built in the last N days. Directories
named "target" without the marker are never touched.

Options:
  --root PATH   Root directory to scan. Repeatable. Defaults to $HOME.
  --days N      Targets with no modification in the last N days are stale. Defaults to 7.
  --dry-run     Print planned removals without deleting anything.
  -h, --help    Show this help.
USAGE
}

roots=()
days=7
dry_run=0

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
        --days)
            if [ "$#" -lt 2 ] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
                echo "error: --days requires a positive integer" >&2
                exit 2
            fi
            days="$2"
            shift 2
            ;;
        --dry-run)
            dry_run=1
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

human_size() {
    local kib="$1"
    awk -v kib="$kib" 'BEGIN {
        split("K M G T", units, " ")
        value = kib
        unit = 1
        while (value >= 1024 && unit < 4) {
            value /= 1024
            unit++
        }
        if (value == int(value)) {
            printf "%d%s", value, units[unit]
        } else {
            printf "%.1f%s", value, units[unit]
        }
    }'
}

# Print the cwd of each running process, one per line. Linux has /proc; on
# systems without it (macOS) fall back to lsof, and give up silently if the
# system has neither.
process_cwds() {
    local pid_dir

    if [ -d /proc ]; then
        for pid_dir in /proc/[0-9]*; do
            [ -e "$pid_dir/cwd" ] || continue
            readlink "$pid_dir/cwd" 2>/dev/null || true
        done
    elif command -v lsof >/dev/null 2>&1; then
        lsof -a -d cwd -Fn 2>/dev/null | sed -n 's/^n//p'
    fi
}

parent_in_use() {
    local parent="$1"
    local parent_real cwd

    # lsof reports cwds with symlinks resolved (/var -> /private/var on macOS),
    # and the parent comes from an unresolved find path; resolve before comparing.
    parent_real="$(realpath "$parent" 2>/dev/null || printf '%s\n' "$parent")"
    while IFS= read -r cwd; do
        case "$cwd" in
            "$parent_real"|"$parent_real"/*) return 0 ;;
        esac
    done < <(process_cwds)
    return 1
}

minutes=$((days * 1440))
removed=0
kept=0
skipped=0
failed=0
freed_kib=0

for root in "${roots[@]}"; do
    if [ ! -d "$root" ]; then
        echo "skip root (not a directory): $root" >&2
        continue
    fi

    while IFS= read -r target; do
        [ -n "$target" ] || continue

        if [ -n "$(find "$target" -maxdepth 3 -mmin "-$minutes" -print -quit 2>/dev/null)" ]; then
            kept=$((kept + 1))
            continue
        fi

        parent="$(dirname "$target")"
        if parent_in_use "$parent"; then
            echo "SKIP in use: $target"
            skipped=$((skipped + 1))
            continue
        fi

        size_kib="$(du -sk "$target" 2>/dev/null | awk '{print $1}')"
        [ -n "$size_kib" ] || size_kib=0
        size="$(human_size "$size_kib")"

        if [ "$dry_run" -eq 1 ]; then
            echo "WOULD remove stale cargo target: $target ($size)"
            removed=$((removed + 1))
            freed_kib=$((freed_kib + size_kib))
            continue
        fi

        if rm -rf "$target"; then
            echo "OK removed stale cargo target: $target ($size)"
            removed=$((removed + 1))
            freed_kib=$((freed_kib + size_kib))
        else
            echo "FAIL remove stale cargo target: $target ($size)" >&2
            failed=$((failed + 1))
        fi
    done < <(
        find "$root" \
            \( -type d \( -name .git -o -name node_modules -o -name .venv -o -name .cache \) -prune \) \
            -o \( -type d -name target -exec test -f '{}/CACHEDIR.TAG' \; -print -prune \) 2>/dev/null
    )
done

freed="$(human_size "$freed_kib")"
if [ "$dry_run" -eq 1 ]; then
    echo "Summary: removed=$removed kept=$kept skipped=$skipped failed=$failed would_free=$freed"
else
    echo "Summary: removed=$removed kept=$kept skipped=$skipped failed=$failed freed=$freed"
fi

if [ "$failed" -gt 0 ]; then
    exit 1
fi
