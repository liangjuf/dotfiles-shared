#!/usr/bin/env bash
# init-omz.sh — clone Oh My Zsh + plugins (never run upstream installer; preserves .zshrc).
# Usage: init-omz.sh
set -euo pipefail

OMZ_DIR="${OMZ_DIR:-$HOME/.oh-my-zsh}"
OMZ_CUSTOM_DIR="$OMZ_DIR/custom"
OMZ_PLUGINS_DIR="$OMZ_CUSTOM_DIR/plugins"
OMZ_THEMES_DIR="$OMZ_CUSTOM_DIR/themes"

log() { echo "[init-omz] $*"; }

clone_if_missing() {
    local name="$1"
    local repo="$2"
    local dest="$3"
    if [ -d "$dest" ]; then
        log "✓ $name already installed"
        return 0
    fi
    log "Installing $name..."
    git clone --depth=1 "$repo" "$dest" || log "⚠ Failed to install $name"
}

log "Configuring Oh My Zsh..."
clone_if_missing "Oh My Zsh" https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR"
mkdir -p "$OMZ_PLUGINS_DIR" "$OMZ_THEMES_DIR"
clone_if_missing "powerlevel10k" https://github.com/romkatv/powerlevel10k.git "$OMZ_THEMES_DIR/powerlevel10k"
clone_if_missing "zsh-autosuggestions" https://github.com/zsh-users/zsh-autosuggestions "$OMZ_PLUGINS_DIR/zsh-autosuggestions"
clone_if_missing "zsh-syntax-highlighting" https://github.com/zsh-users/zsh-syntax-highlighting "$OMZ_PLUGINS_DIR/zsh-syntax-highlighting"
