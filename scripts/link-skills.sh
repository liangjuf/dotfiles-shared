#!/usr/bin/env bash
# link-skills.sh — symlink shared + optional role-tier skills into agent skill dirs.
# Usage: link-skills.sh [tier] [consumer_root]
#   tier: devspace | personal (optional — shared tier is always linked)
#   consumer_root: lfeng/dotfiles or liangjuf/dotfiles root (required when tier is set)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="${SHARED:-$(cd "$SCRIPT_DIR/.." && pwd)}"
TIER="${1:-}"
CONSUMER_ROOT="${2:-${DOTFILES_ROOT:-}}"

CLAUDE_SKILLS="${CLAUDE_SKILLS:-$HOME/.claude/skills}"
CODEX_SKILLS="${CODEX_SKILLS:-$HOME/.codex/skills}"

log() { echo "[link-skills] $*"; }

link_skill() {
    local src="$1" dest_root="$2"
    local name dest
    name="$(basename "$src")"
    dest="$dest_root/$name"

    mkdir -p "$dest_root"
    if [ -L "$dest" ]; then
        rm "$dest"
    elif [ -e "$dest" ]; then
        echo "[link-skills] error: $dest exists and is not a symlink" >&2
        return 1
    fi
    ln -sfn "$src" "$dest"
    log "linked $name → $dest_root"
}

link_tier() {
    local tier_dir="$1"
    local dest_root="$2"

    [ -d "$tier_dir" ] || return 0

    local skill
    for skill in "$tier_dir"/*/; do
        [ -d "$skill" ] || continue
        [ -f "$skill/SKILL.md" ] || continue
        link_skill "$skill" "$dest_root"
    done
}

link_all_tiers() {
    local dest_root="$1"

    link_tier "$SHARED/skills/shared" "$dest_root"

    if [ -n "$TIER" ]; then
        if [ -z "$CONSUMER_ROOT" ]; then
            echo "[link-skills] error: consumer root required when tier is set (arg 2 or DOTFILES_ROOT)" >&2
            exit 1
        fi
        link_tier "$CONSUMER_ROOT/skills/$TIER" "$dest_root"
    fi
}

for dest_root in "$CLAUDE_SKILLS" "$CODEX_SKILLS"; do
    link_all_tiers "$dest_root"
done
