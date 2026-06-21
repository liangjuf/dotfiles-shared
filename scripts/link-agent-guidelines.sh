#!/usr/bin/env bash
# link-agent-guidelines.sh — symlink shared AGENTS.md into agent config dirs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="${SHARED:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SRC="$SHARED/agents/AGENTS.md"

CLAUDE_AGENTS="${CLAUDE_AGENTS:-$HOME/.claude/AGENTS.md}"
CODEX_AGENTS="${CODEX_AGENTS:-$HOME/.codex/AGENTS.md}"
CURSOR_AGENTS="${CURSOR_AGENTS:-$HOME/.cursor/AGENTS.md}"

AGENT_GUIDELINE_DESTS=("$CLAUDE_AGENTS" "$CODEX_AGENTS" "$CURSOR_AGENTS")

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
