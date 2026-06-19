# Work Coder devspace overlay — sourced after shared zsh/*.zsh

# --- Ghostty SSH Split ---
_DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.config/coderv2/dotfiles}"
[[ -r "$_DOTFILES_DIR/ssht.zsh" ]] && source "$_DOTFILES_DIR/ssht.zsh"

cmux() {
  if [[ "$1" == "ssh" && -n "$2" && -n "$3" && $# -eq 3 ]]; then
    ssht --cmux "$2" "$3"
  else
    command cmux "$@"
  fi
}

# --- AWS (Roblox MLP) ---
export AWS_PROFILE=mlp
export USERNAME=lfeng

# --- Secrets (gopass) ---
[[ -r "$_DOTFILES_DIR/scripts/roblox-secrets.zsh" ]] && \
  source "$_DOTFILES_DIR/scripts/roblox-secrets.zsh"

aws_sso() {
  if ! aws sts get-caller-identity &>/dev/null; then
    echo "AWS SSO session expired, logging in..."
    aws sso login --profile "$AWS_PROFILE" --use-device-code
  fi
}

s3() {
  aws_sso
  aws s3 "$@"
}

# --- Auto-open Cursor Workspace (devspace) ---
_CURSOR_LOG="/tmp/cursor-workspace.log"
_WORKSPACE_FILE="$HOME/repos.code-workspace"
_WORKSPACE_LOCK="/tmp/.cursor-workspace.lock"
_SESSION_MARKER_PREFIX="/tmp/.cursor-workspace-opened-"

_log_cursor() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$_CURSOR_LOG"; }
_log_cursor "--- zshrc auto-open section started ---"

_EXTENSIONS_MARKER="$HOME/.cursor-extensions-installed"
_EXTENSIONS_FILE="$_DOTFILES_DIR/cursor-extensions.txt"
_SKILLS_MARKER="$HOME/.cursor-skills-installed-v4"
_SUPERPOWERS_SKILL_URL="https://github.com/obra/superpowers"
_LOCAL_SKILLS_PATH="$_DOTFILES_DIR/skills"
_SKILLS_AGENTS=(-a claude-code -a cursor)

if [[ -n "$VSCODE_IPC_HOOK_CLI" && ! -f "$_EXTENSIONS_MARKER" && -f "$_EXTENSIONS_FILE" ]]; then
  _log_cursor "Installing Cursor extensions (one-time)"
  cursor_bin=$(find "$HOME/.cursor-server/bin" -name "cursor" -path "*/remote-cli/*" 2>/dev/null | head -1)
  if [[ -x "$cursor_bin" ]]; then
    total=$(grep -cvE '^($|#)' "$_EXTENSIONS_FILE")
    count=0
    failed=0
    while IFS= read -r ext; do
      [[ -z "$ext" || "$ext" == \#* ]] && continue
      ((count++))
      if "$cursor_bin" --install-extension "$ext" &>/dev/null; then
        _log_cursor "[$count/$total] ✓ $ext"
      else
        _log_cursor "[$count/$total] ✗ $ext (failed)"
        ((failed++))
      fi
    done < "$_EXTENSIONS_FILE"
    touch "$_EXTENSIONS_MARKER"
    _log_cursor "Extensions complete: $((count - failed))/$count succeeded"
  fi
fi

if [[ -n "$VSCODE_IPC_HOOK_CLI" && ! -f "$_SKILLS_MARKER" ]]; then
  if command -v npx >/dev/null 2>&1; then
    _skills_install_failed=0
    if npx --yes skills add "$_SUPERPOWERS_SKILL_URL" --global -s '*' "${_SKILLS_AGENTS[@]}" -y </dev/null &>/dev/null; then
      _log_cursor "Superpowers skills install succeeded"
    else
      _skills_install_failed=1
    fi
    if [[ -d "$_LOCAL_SKILLS_PATH" ]]; then
      npx --yes skills add "$_LOCAL_SKILLS_PATH" --global -s '*' "${_SKILLS_AGENTS[@]}" -y </dev/null &>/dev/null || _skills_install_failed=1
    else
      _skills_install_failed=1
    fi
    [[ "$_skills_install_failed" -eq 0 ]] && touch "$_SKILLS_MARKER"
  fi
fi

if [[ "${ENABLE_CURSOR_WORKSPACE_AUTO_OPEN:-0}" == "1" && -n "$VSCODE_IPC_HOOK_CLI" && -z "$CURSOR_AGENT" ]]; then
  _SESSION_HASH=$(printf '%s' "$VSCODE_IPC_HOOK_CLI" | md5sum | awk '{print $1}')
  _SESSION_MARKER="${_SESSION_MARKER_PREFIX}${_SESSION_HASH}"
  (
    flock -n 9 || exit 0
    [[ -f "$_SESSION_MARKER" ]] && exit 0
    if [[ -f "$_WORKSPACE_FILE" ]]; then
      touch "$_SESSION_MARKER"
      sleep 1
      command -v cursor >/dev/null 2>&1 && cursor -r "$_WORKSPACE_FILE" >/dev/null 2>&1 || rm -f "$_SESSION_MARKER"
    fi
  ) 9>"$_WORKSPACE_LOCK" &!
fi

alias cc='CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000 claude --dangerously-skip-permissions'
alias cx='codex --dangerously-bypass-approvals-and-sandbox'

unset _DOTFILES_DIR _CURSOR_LOG _WORKSPACE_FILE _WORKSPACE_LOCK _SESSION_MARKER_PREFIX
