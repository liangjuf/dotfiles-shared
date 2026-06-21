#!/usr/bin/env bash
# link-agent-guidelines.sh — symlink shared AGENTS.md into agent global config paths.
# Codex reads ~/.codex/AGENTS.md; Claude Code reads ~/.claude/CLAUDE.md (not AGENTS.md).
# Cursor uses project-root AGENTS.md and ~/.cursor/rules/ — no global ~/.cursor/AGENTS.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="${SHARED:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SRC="$SHARED/agents/AGENTS.md"

CLAUDE_GUIDELINES="${CLAUDE_GUIDELINES:-$HOME/.claude/CLAUDE.md}"
CODEX_GUIDELINES="${CODEX_GUIDELINES:-$HOME/.codex/AGENTS.md}"

AGENT_GUIDELINE_DESTS=("$CLAUDE_GUIDELINES" "$CODEX_GUIDELINES")

log() { echo "[link-agent-guidelines] $*"; }

link_guidelines() {
    local dest="$1"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    if [ ! -f "$SRC" ]; then
        echo "[link-agent-guidelines] error: source not found: $SRC" >&2
        return 1
    fi

    mkdir -p "$dest_dir"
    if [ -L "$dest" ]; then
        rm "$dest"
    elif [ -e "$dest" ]; then
        echo "[link-agent-guidelines] error: $dest exists and is not a symlink" >&2
        return 1
    fi
    ln -sfn "$SRC" "$dest"
    log "linked → $dest"
}

for dest in "${AGENT_GUIDELINE_DESTS[@]}"; do
    link_guidelines "$dest"
done
