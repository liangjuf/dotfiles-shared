# --- Navigation & history tools ---
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v atuin &>/dev/null && eval "$(atuin init zsh)"

# --- NVM ---
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

# --- FZF ---
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"

# --- Aliases ---
command -v eza &>/dev/null && alias ls="eza"
command -v z &>/dev/null && alias cd="z"
alias ll="ls -lah"

# --- GPG / pass (interactive shells) ---
if [[ -o interactive && -t 0 ]]; then
  export GPG_TTY="$(tty)"
  gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
fi

export CLAUDE_CODE_NO_FLICKER=1
