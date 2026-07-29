#!/bin/bash
set -eu

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

PREFERRED_SHELL="${PREFERRED_SHELL:-bash}"

if [ "$PREFERRED_SHELL" = "zsh" ]; then
  # --- Install zsh plugins (idempotent) ---
  mkdir -p "$HOME/.zsh"
  [ ! -d "$HOME/.zsh/zsh-autosuggestions" ] && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
  [ ! -d "$HOME/.zsh/zsh-syntax-highlighting" ] && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting

  # --- Symlink shared config ---
  mkdir -p ~/.config
  ln -sf "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml

  # --- Write ~/.zshrc (idempotent guard) ---
  if ! grep -q 'AQEMIA_DOTFILES' ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc <<ZSHRC

# AQEMIA_DOTFILES
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Starship + zoxide
command -v starship &>/dev/null && eval "\$(starship init zsh)"
command -v zoxide &>/dev/null && eval "\$(zoxide init --cmd cd zsh)"

# History
export HISTFILE="\$HOME/.zsh_history"
export HISTSIZE=2000000
export SAVEHIST=2000000
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY

export EDITOR=vim
export KUBE_EDITOR=vim

# Go / Cargo / Krew
GOPATH=\${HOME}/go
export PATH=\$PATH:\$GOPATH/bin:\$HOME/.cargo/bin:\${KREW_ROOT:-\$HOME/.krew}/bin

# Aliases
source "$DOTFILES_DIR/aliases/custom.bash"

# Terraform cache
export TF_PLUGIN_CACHE_DIR=\$HOME/.terraform.d/plugin-cache
export TG_PROVIDER_CACHE=true
ZSHRC
  fi

  # chsh fails in containers (PAM requires a password). Fall back to exec-ing zsh
  # from ~/.bash_profile so any bash login shell (coder ssh, web terminal) switches
  # to zsh automatically.
  ZSH_PATH=$(command -v zsh)
  chsh -s "$ZSH_PATH" || true

  # Break symlink if present (may exist when switching from bash), then append exec
  [ -L ~/.bash_profile ] && cp -L ~/.bash_profile ~/.bash_profile.tmp && mv ~/.bash_profile.tmp ~/.bash_profile 2>/dev/null || true
  if ! grep -q 'AQEMIA_SHELL_SWITCH' ~/.bash_profile 2>/dev/null; then
    cat >> ~/.bash_profile <<PROFILE

# AQEMIA_SHELL_SWITCH - exec into zsh when chsh is unavailable (container environments)
[ -n "\$PS1" ] && exec "$ZSH_PATH" -l
PROFILE
  fi

else
  # --- Install bash-it ---
  if [ ! -d "$HOME/.bash_it" ]; then
      echo "Installing bash-it..."
      git clone --depth=1 https://github.com/Bash-it/bash-it.git "$HOME/.bash_it"
  fi

  # --- Enable bash-it components via symlinks ---
  mkdir -p "$HOME/.bash_it/enabled"

  # Aliases
  for a in bash-it directory editor general; do
      ln -sf "$HOME/.bash_it/aliases/available/${a}.aliases.bash" \
             "$HOME/.bash_it/enabled/150---${a}.aliases.bash" 2>/dev/null || true
  done

  # Plugins
  ln -sf "$HOME/.bash_it/plugins/available/base.plugin.bash" \
         "$HOME/.bash_it/enabled/250---base.plugin.bash"

  # Completions
  for c in system bash-it docker git github-cli go kubectl terraform; do
      ln -sf "$HOME/.bash_it/completion/available/${c}.completion.bash" \
             "$HOME/.bash_it/enabled/350---${c}.completion.bash" 2>/dev/null || true
  done
  ln -sf "$HOME/.bash_it/completion/available/system.completion.bash" \
         "$HOME/.bash_it/enabled/325---system.completion.bash"
  ln -sf "$HOME/.bash_it/completion/available/aliases.completion.bash" \
         "$HOME/.bash_it/enabled/800---aliases.completion.bash"

  # --- Symlink config files ---
  mkdir -p ~/.config ~/.bash_it/custom ~/.bash_it/aliases

  ln -sf "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml
  ln -sf "$DOTFILES_DIR/custom/custom.bash" ~/.bash_it/custom/custom.bash
  ln -sf "$DOTFILES_DIR/aliases/custom.bash" ~/.bash_it/aliases/custom.bash

  # --- Ensure .bash_profile sources .bashrc (login shells) ---
  # Remove any zsh exec switch before symlinking (handles zsh→bash switch)
  if [ -f ~/.bash_profile ] && ! [ -L ~/.bash_profile ]; then
    sed -i '/# AQEMIA_SHELL_SWITCH/,+2d' ~/.bash_profile 2>/dev/null || true
  fi
  ln -sf "$DOTFILES_DIR/.bash_profile" ~/.bash_profile

  # --- Prepend interactive-shell guard to ~/.bashrc ---
  # Bash sources ~/.bashrc even non-interactively when stdin is a network
  # socket (rshd/sshd detection — `coder ssh` / Tailscale SSH trigger this).
  # Without an early return, bash-it's `bind` calls error with "line editing
  # not enabled", and any git config in user-sourced files (e.g. a personal
  # ~/.personalize.bashrc) can race the workspace's git startup script on
  # ~/.gitconfig.lock. Prepending the standard Ubuntu skel guard makes
  # everything below it interactive-only. Idempotent via marker.
  if [ -f ~/.bashrc ] && ! grep -q 'AQEMIA_INTERACTIVE_GUARD' ~/.bashrc; then
    tmp=$(mktemp)
    {
      printf '%s\n' '# AQEMIA_INTERACTIVE_GUARD: return early when not interactive'
      printf '%s\n' 'case $- in'
      printf '%s\n' '    *i*) ;;'
      printf '%s\n' '      *) return;;'
      printf '%s\n\n' 'esac'
      cat ~/.bashrc
    } > "$tmp"
    mv "$tmp" ~/.bashrc
  fi

  # --- Ensure .bashrc loads bash-it ---
  if ! grep -q 'BASH_IT' ~/.bashrc 2>/dev/null; then
      cat >> ~/.bashrc <<'BASHRC'

# bash-it
export BASH_IT="$HOME/.bash_it"
export BASH_IT_THEME='pure'
export SCM_CHECK=true
unset MAILCHECK
source "$BASH_IT/bash_it.sh"
BASHRC
  fi

fi

# ============================================================================
# Base extras - apply to any Coder workspace (zellij, mosh-server + UTF-8
# locales). Idempotent. Engineering-specific tooling lives in engineering/ and
# is wired in at the very end of this script, only if that directory exists.
# ============================================================================

# --- Extra mise-managed tools ---
if command -v mise >/dev/null 2>&1; then
  mise use -g zellij@latest || true
fi

# --- Zellij config + zellaude layout ---
# Symlink our zellij config/layout in. The zellaude plugin referenced in
# layouts/default.kdl is fetched by zellij on first use and self-installs its
# Claude Code hooks into ~/.claude/settings.json, so only these two files need
# version-controlling.
if [ -d "$DOTFILES_DIR/.config/zellij" ]; then
  mkdir -p "$HOME/.config/zellij/layouts"
  ln -sf "$DOTFILES_DIR/.config/zellij/config.kdl"          "$HOME/.config/zellij/config.kdl"
  ln -sf "$DOTFILES_DIR/.config/zellij/layouts/default.kdl" "$HOME/.config/zellij/layouts/default.kdl"

  # Pre-grant zellaude's plugin permissions so the first-run permission popup
  # doesn't block users who miss it. Scoped to the exact pinned plugin URL (keep
  # in sync with layouts/default.kdl); appended idempotently so other plugins'
  # grants are never clobbered. This pre-approves ONLY this reviewed plugin -
  # zellij has no blanket "trust all plugins" switch, by design.
  zj_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zellij"
  mkdir -p "$zj_cache"
  if ! grep -q 'zellaude/releases/download/v0.5.0' "$zj_cache/permissions.kdl" 2>/dev/null; then
    cat >> "$zj_cache/permissions.kdl" <<'KDL'

"https://github.com/ishefi/zellaude/releases/download/v0.5.0/zellaude.wasm" {
    ReadCliPipes
    MessageAndLaunchOtherPlugins
    ReadApplicationState
    ChangeApplicationState
    RunCommands
}
KDL
  fi
fi

# --- mosh-server + UTF-8 locales (no root; conda + ~/.locale) ---
# mosh isn't in the mise registry and apt needs root, so install the conda-forge
# build into an isolated prefix. mosh forwards the client's LANG (e.g.
# en_GB.UTF-8) but the image ships only C.UTF-8 / en_US.UTF-8 and locale-gen
# needs root, so compile the locales we use into ~/.locale.
MOSH_PREFIX="$HOME/.local/mosh"
CONDA_BIN="$(command -v conda || echo /opt/conda/bin/conda)"
if [ ! -x "$MOSH_PREFIX/bin/mosh-server" ] && [ -x "$CONDA_BIN" ]; then
  echo "Installing mosh-server via conda..."
  "$CONDA_BIN" create -y -p "$MOSH_PREFIX" -c conda-forge mosh || true
fi

LOCALE_DIR="$HOME/.locale"
if command -v localedef >/dev/null 2>&1; then
  for loc in en_GB en_US; do
    if [ ! -d "$LOCALE_DIR/${loc}.UTF-8" ] && [ -f "/usr/share/i18n/locales/${loc}" ]; then
      echo "Compiling ${loc}.UTF-8 locale into $LOCALE_DIR..."
      mkdir -p "$LOCALE_DIR"
      localedef -i "$loc" -f UTF-8 "$LOCALE_DIR/${loc}.UTF-8" || true
    fi
  done
fi

# Wire mosh-server's PATH + UTF-8 locale into the shell startup files. The mosh
# client runs `mosh-server` over a NON-interactive ssh command, so the env must
# reach non-interactive shells:
#   bash: prepend to ~/.bashrc ABOVE the AQEMIA_INTERACTIVE_GUARD - a plain
#         append would sit below the guard's early `return` and never run for
#         sshd-spawned shells.
#   zsh : append to ~/.zshenv (always sourced, even non-interactively).
if [ -x "$MOSH_PREFIX/bin/mosh-server" ] && [ -d "$LOCALE_DIR/en_GB.UTF-8" ]; then
  if [ -f ~/.bashrc ] && ! grep -q 'AQEMIA_MOSH_ENV' ~/.bashrc 2>/dev/null; then
    tmp=$(mktemp)
    cat > "$tmp" <<EOF
# AQEMIA_MOSH_ENV - must be ABOVE the interactive guard: the mosh client runs
# \`mosh-server\` via a non-interactive ssh command, and bash returns early at
# the guard for sshd-spawned shells, so mosh-server's PATH and a resolvable
# UTF-8 locale have to be set here first.
export LOCPATH="\$HOME/.locale"
export LANG="en_GB.UTF-8"
export PATH="$MOSH_PREFIX/bin:\$PATH"

EOF
    cat ~/.bashrc >> "$tmp"
    mv "$tmp" ~/.bashrc
  fi
  if ! grep -q 'AQEMIA_MOSH_ENV' ~/.zshenv 2>/dev/null; then
    cat >> ~/.zshenv <<EOF

# AQEMIA_MOSH_ENV
export LOCPATH="\$HOME/.locale"
export LANG="en_GB.UTF-8"
export PATH="$MOSH_PREFIX/bin:\$PATH"
EOF
  fi
fi

# ============================================================================
# Engineering layer (optional). Runs only if the engineering/ directory is
# present - delete that directory for a general-purpose, copy-anywhere setup.
# Set DOTFILES_NO_ENGINEERING=1 to skip it while keeping the files.
# engineering/shell.bash is symlinked into ~/.bash_it/custom/ (bash-it auto-
# sources custom/*.bash); engineering/install.sh does the install-time steps.
# ============================================================================
ENG_DIR="$DOTFILES_DIR/engineering"
ENG_LINK="$HOME/.bash_it/custom/engineering.bash"
if [ -d "$ENG_DIR" ] && [ "${DOTFILES_NO_ENGINEERING:-0}" != "1" ]; then
  mkdir -p "$HOME/.bash_it/custom"
  ln -sf "$ENG_DIR/shell.bash" "$ENG_LINK"
  # shellcheck source=/dev/null
  . "$ENG_DIR/install.sh"
else
  rm -f "$ENG_LINK"
fi

echo "Dotfiles installed successfully."
