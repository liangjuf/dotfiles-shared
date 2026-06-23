#!/usr/bin/env bash
# ensure-tmux-plugins.sh — idempotent TPM + plugin install for shared tmux.conf
# Usage: ensure-tmux-plugins.sh [path/to/tmux.conf]

set -euo pipefail

log() { echo "[ensure-tmux-plugins] $*"; }

TPM_DIR="${HOME}/.tmux/plugins/tpm"
TMUX_CONF="${1:-${HOME}/.tmux.conf}"

if [[ ! -f "$TMUX_CONF" ]]; then
    log "skip: $TMUX_CONF not found"
    exit 0
fi

if ! command -v tmux &>/dev/null; then
    log "skip: tmux not installed"
    exit 0
fi

if [[ ! -d "$TPM_DIR" ]]; then
    log "Installing TPM..."
    mkdir -p "${HOME}/.tmux/plugins"
    if ! git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"; then
        log "warning: TPM clone failed"
        exit 0
    fi
    log "TPM installed"
fi

if [[ -x "$TPM_DIR/bin/install_plugins" ]]; then
    log "Installing tmux plugins..."
    if tmux -L tpm -f "$TMUX_CONF" start-server \; \
        run-shell "$TPM_DIR/bin/install_plugins" \; \
        kill-server 2>/dev/null; then
        log "tmux plugins up to date"
    else
        log "warning: plugin install failed"
    fi
fi
