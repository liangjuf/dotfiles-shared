#!/usr/bin/env bash
# Source shared zsh files from a known directory.
# Usage: DOTFILES_SHARED=/path/to/shared source source-shared-zsh.sh [role-overlay-name]

set -euo pipefail

shared="${DOTFILES_SHARED:?DOTFILES_SHARED must be set}"
role="${1:-}"

if [[ -d "$shared/zsh" ]]; then
  for f in "$shared/zsh"/*.zsh(N); do
    # shellcheck source=/dev/null
    source "$f"
  done
fi

if [[ -n "$role" && -f "$shared/overlays/${role}.zsh" ]]; then
  # shellcheck source=/dev/null
  source "$shared/overlays/${role}.zsh"
fi
