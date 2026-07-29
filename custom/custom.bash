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
# Personal additions (ported from ~/personalize). Interactive-shell config;
# install-time steps live in install.sh.
# ============================================================================

# 1Password service-account token. The token lives in a 0600 file in $HOME
# (persistent) and is NEVER committed to this repo; source it only if present.
[ -f ~/.op-sa.env ] && source ~/.op-sa.env

# mise: export the shared-config env BEFORE activating, otherwise `mise activate`
# skips /opt/mise/config.toml and tools like Go are not put on PATH.
export MISE_GLOBAL_CONFIG_FILE=/opt/mise/config.toml
export MISE_DATA_DIR=/opt/mise
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"

# Cycle through command history with the arrow keys (interactive shells only)
if [[ $- == *i* ]]; then
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
fi

# connect_to_db <env>: open a psql session against a database selected by a short
# name. The env->AWS-profile map, the Secrets Manager secret id, and the JSON key
# holding the DSN are all read from ~/.connect_to_db.env (0600, kept in $HOME,
# never committed) so no environment or target names appear in this repo.
# Example ~/.connect_to_db.env:
#   CONNECT_DB_SECRET_ID="<secretsmanager-secret-id>"
#   CONNECT_DB_DSN_KEY="<json-key-holding-the-dsn>"
#   CONNECT_DB_PROFILES=( [envname]=awsprofile [other]=otherprofile )
connect_to_db() {
    local cfg="$HOME/.connect_to_db.env"
    local -A CONNECT_DB_PROFILES=()
    local CONNECT_DB_SECRET_ID="" CONNECT_DB_DSN_KEY=""

    if [ ! -f "$cfg" ]; then
        echo "connect_to_db: $cfg not found - it must define CONNECT_DB_PROFILES, CONNECT_DB_SECRET_ID and CONNECT_DB_DSN_KEY" >&2
        return 1
    fi
    source "$cfg"

    if [ -z "${1:-}" ] || [ -z "${CONNECT_DB_PROFILES[${1:-_}]:-}" ]; then
        [ -n "${1:-}" ] && echo "Unknown environment: $1" >&2
        echo "Usage: connect_to_db <environment>" >&2
        echo "Available environments: ${!CONNECT_DB_PROFILES[*]}" >&2
        return 1
    fi
    if [ -z "$CONNECT_DB_SECRET_ID" ] || [ -z "$CONNECT_DB_DSN_KEY" ]; then
        echo "connect_to_db: CONNECT_DB_SECRET_ID / CONNECT_DB_DSN_KEY not set in $cfg" >&2
        return 1
    fi

    psql "$(aws secretsmanager get-secret-value \
              --secret-id "$CONNECT_DB_SECRET_ID" \
              --profile "${CONNECT_DB_PROFILES[$1]}" \
              --query 'SecretString' --output text | jq -r ".\"$CONNECT_DB_DSN_KEY\"")"
}

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
