#!/usr/bin/env bash

# Starship prompt
command -v starship &>/dev/null && eval "$(starship init bash)"

# Zoxide (cd replacement)
command -v zoxide &>/dev/null && eval "$(zoxide init --cmd cd bash)"

# History settings
export HISTSIZE=2000000
export HISTFILESIZE=3000000
export TIMEFORMAT=$'\nreal %3R\tuser %3U\tsys %3S\tpcpu %P\n'
export HISTTIMEFORMAT="%d/%m/%Y - %H:%M:%S > "
export HISTIGNORE="&:bg:fg:ll:"

export EDITOR=vim
export KUBE_EDITOR=vim

# AWS CLI completer
_aws_completer=$(command -v aws_completer 2>/dev/null)
[[ -n "$_aws_completer" ]] && complete -C "$_aws_completer" aws

# gh completion (fallback if bash-it github-cli completion isn't loaded)
if command -v gh &>/dev/null && ! complete -p gh &>/dev/null 2>&1; then
    eval "$(gh completion -s bash)"
fi

# Go
GOPATH=${HOME}/go
PATH=${PATH}:${GOPATH}/bin

# Cargo (Rust)
export PATH=$PATH:$HOME/.cargo/bin

# Krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Custom aliases
source ~/.bash_it/aliases/custom.bash

# FZF
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Terragrunt cache
export TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache
export TG_PROVIDER_CACHE=true

# ============================================================================
# Base interactive config - applies to any workspace. Engineering-specific shell
# bits (1Password token, connect_to_db) live in engineering/shell.bash, which
# bash-it auto-loads from ~/.bash_it/custom/ when the engineering layer is on.
# ============================================================================

# mise: export the shared-config env BEFORE activating, otherwise `mise activate`
# skips the shared config and tools like Go are not put on PATH. Guarded on the
# Coder image's shared config path so this stays harmless elsewhere.
if [ -f /opt/mise/config.toml ]; then
  export MISE_GLOBAL_CONFIG_FILE=/opt/mise/config.toml
  export MISE_DATA_DIR=/opt/mise
fi
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"

# Cycle through command history with the arrow keys (interactive shells only)
if [[ $- == *i* ]]; then
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
fi

# Refresh AWS Pod-Identity + CodeArtifact creds in the current shell. Useful
# inside long-lived tmux/zellij panes where the periodic refresh hasn't landed.
refresh-creds() {
  local shared=~/repos/engineering/infra/aws/modules/coder-management/templates/_shared
  if [ ! -d "$shared" ]; then
    echo "refresh-creds: $shared not found - is the engineering repo checked out?" >&2
    return 1
  fi
  bash "$shared/aws-credentials.sh"   || return $?
  bash "$shared/codeartifact-auth.sh" || return $?
  [ -f ~/.codeartifact.env ] && source ~/.codeartifact.env
  [ -f ~/.aws-pod-identity.env ] && source ~/.aws-pod-identity.env
}
