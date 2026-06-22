# personal-ec2 overlay

export WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/personal}"

command -v npm &>/dev/null && export PATH="$(npm prefix -g)/bin:$PATH"

alias oc=openclaw
