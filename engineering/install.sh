#!/bin/bash
# Engineering-only install steps (observability MCPs, 1Password CLI).
# Sourced by the repo's top-level install.sh when the engineering/ directory is
# present, so it runs in that script's shell (bash, `set -eu`). All idempotent.

# --- Bridge Coder git credentials into the gh CLI ---
# Coder auths git HTTPS via GIT_ASKPASS but not `gh` itself. Without this the
# release downloads below fall back to anonymous and hit API rate limits.
if ! gh auth status -h github.com >/dev/null 2>&1 && [ -s ~/.git-credentials ]; then
  awk -F'[:@]' '/x-access-token/{print $3}' ~/.git-credentials \
    | gh auth login --hostname github.com --with-token >/dev/null 2>&1 || true
fi

# --- observability-core plugin MCP binaries -> ~/.local/bin (persistent) ---
# The plugin ships .mcp.json but not the binaries; on Coder Linux workspaces we
# install them ourselves from upstream releases.
mkdir -p ~/.local/bin
install_obs_mcp() {
  local repo=$1 bin=$2
  command -v "$bin" >/dev/null 2>&1 && return 0
  local tmp; tmp=$(mktemp -d)
  gh release download --repo "$repo" --pattern "${bin}_Linux_x86_64.tar.gz" --dir "$tmp" \
    && tar -xzf "$tmp/${bin}_Linux_x86_64.tar.gz" -C "$tmp" "$bin" \
    && install -m 0755 "$tmp/$bin" ~/.local/bin/
  rm -rf "$tmp"
}
install_obs_mcp VictoriaMetrics-Community/mcp-victoriametrics mcp-victoriametrics || true
install_obs_mcp VictoriaMetrics-Community/mcp-victorialogs    mcp-victorialogs    || true
install_obs_mcp grafana/mcp-grafana                           mcp-grafana         || true

# --- 1Password CLI -> ~/.local/bin (persistent) ---
# https://www.1password.dev/cli/get-started#linux-2
install_op_cli() {
  command -v op >/dev/null 2>&1 && return 0
  local version tmp
  version=$(curl -fsSL "https://app-updates.agilebits.com/check/1/0/CLI2/en/2.0.0/N" 2>/dev/null | jq -r .version)
  if [ -z "$version" ] || [ "$version" = "null" ]; then
    echo "install_op_cli: failed to determine latest version" >&2
    return 1
  fi
  tmp=$(mktemp -d)
  curl -fsSL "https://cache.agilebits.com/dist/1P/op2/pkg/v${version}/op_linux_amd64_v${version}.zip" -o "$tmp/op.zip" \
    && unzip -q "$tmp/op.zip" -d "$tmp" op \
    && install -m 0755 "$tmp/op" ~/.local/bin/
  rm -rf "$tmp"
}
install_op_cli || true
