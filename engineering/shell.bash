#!/usr/bin/env bash
# Engineering-only interactive shell config (1Password token, connect_to_db).
# install.sh symlinks this into ~/.bash_it/custom/ (bash-it auto-sources
# custom/*.bash) when the engineering/ layer is present.

# 1Password service-account token. The token lives in a 0600 file in $HOME
# (persistent) and is NEVER committed to this repo; source it only if present.
[ -f ~/.op-sa.env ] && source ~/.op-sa.env

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
