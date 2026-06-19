# Work MacBook overlay

export AWS_PROFILE=mlp
export USERNAME=lfeng

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

alias cc='CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000 claude --dangerously-skip-permissions'
alias cx='codex --dangerously-bypass-approvals-and-sandbox'

# Work project directories
export WORKSPACE_ROOT="$HOME/work"
