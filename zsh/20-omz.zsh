# --- Oh My Zsh ---
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME="powerlevel10k/powerlevel10k"
export ZVM_VI_INSERT_ESCAPE_BINDKEY=jk

plugins=(
  git
  kubectl
  python
  uv
  vi-mode
  zsh-autosuggestions
  zsh-syntax-highlighting
)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

[[ ! -f "$HOME/.p10k.zsh" ]] || source "$HOME/.p10k.zsh"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=cyan'
