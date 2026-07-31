# coder-dotfiles

Personal [Coder](https://coder.com) workspace dotfiles for **Noah Harrison**, forked from
[`Aqemia/coder-default-dotfiles`](https://github.com/Aqemia/coder-default-dotfiles).

The repo is split into two layers so the general parts are reusable by anyone:

- **General layer** - the base setup (shell framework, prompt, aliases, mise, zellij, mosh). Applies
  to any Coder workspace and is safe to copy/fork.
- **Engineering layer** (`engineering/`) - Aqemia-engineering-only tooling (observability MCPs,
  1Password CLI, `connect_to_db`). **Delete the `engineering/` directory** (or set
  `DOTFILES_NO_ENGINEERING=1`) and you're left with a clean, general-purpose dotfiles repo - no dead
  references, no engineering tooling attempted.

## How Coder uses this

Set the workspace **Dotfiles URL** parameter (Settings -> Parameters) to:

```
git@github.com:aqemia-noah-harrison/coder-dotfiles.git
```

On **every workspace start** Coder clones this repo and runs `install.sh`. Two consequences:

- **It runs every start**, which is how tools reappear after a pod restart (only `/home/coder`
  persists). Everything in `install.sh` is therefore **idempotent** - it checks before installing.
- **The SSH clone uses Coder's own managed git key** (`GIT_SSH_COMMAND=coder gitssh`), *not*
  `~/.ssh/id_ed25519`. That Coder public key (shown in the build log / Coder UI -> SSH Keys) must be
  added to <https://github.com/settings/keys> once, or the clone fails with `Permission denied (publickey)`.

## What this installs & configures

Legend: **[general]** = base layer (much of it inherited from `coder-default-dotfiles`);
**[eng]** = engineering layer, lives in `engineering/`. Tools marked *(configures)* are already in the
workspace image; the dotfiles only wire them up.

### Shell framework & prompt
| Item | Layer | Notes |
|------|-------|-------|
| **bash-it** | [general] | Installed to `~/.bash_it`; theme `pure`, completions (git, docker, kubectl, terraform, gh, go), base plugin. Auto-sources `~/.bash_it/custom/*.bash` |
| **zsh plugins** | [general] | `zsh-autosuggestions` + `zsh-syntax-highlighting` (only when `PREFERRED_SHELL=zsh`) |
| **starship** *(configures)* | [general] | Prompt; k8s segment on, aws/gcloud/container off (see `.config/starship.toml`) |
| **zoxide** *(configures)* | [general] | Smart `cd` |
| Interactive guard in `~/.bashrc` | [general] | Early-returns for non-interactive shells |

### CLI tools installed
| Tool | Layer | Where | Purpose |
|------|-------|-------|---------|
| **zellij** *(via mise)* | [general] | mise global | Terminal multiplexer; config + layout symlinked from `.config/zellij/` |
| **gh-stack** *(gh extension)* | [general] | `gh` extensions | `gh stack` - GitHub stacked PRs (`github/gh-stack`) |
| **zellaude** *(zellij plugin)* | [general] | `.config/zellij/layouts/default.kdl` | Claude Code activity bar. Pinned to `v0.5.0`; zellij fetches the wasm on first use and it auto-installs hooks into `~/.claude/settings.json`. Needs `jq`. `install.sh` pre-grants its zellij plugin permissions (scoped to the pinned URL) so the first-run permission popup is skipped |
| **mosh-server** | [general] | `~/.local/mosh` | Roaming SSH; conda-forge build (no root needed) |
| **UTF-8 locales** | [general] | `~/.locale` | `en_GB.UTF-8` / `en_US.UTF-8` via `localedef` (mosh needs a resolvable UTF-8 locale) |
| **mcp-victoriametrics** | [eng] | `~/.local/bin` | observability-core plugin MCP (metrics) |
| **mcp-victorialogs** | [eng] | `~/.local/bin` | observability-core plugin MCP (logs) |
| **mcp-grafana** | [eng] | `~/.local/bin` | observability-core plugin MCP (Grafana) |
| **op** (1Password CLI) | [eng] | `~/.local/bin` | Secret retrieval |

The engineering installer also bridges `gh` to the Coder git token so `gh release download` (used to
fetch the MCP binaries) is authenticated rather than anonymous/rate-limited.

### Shell environment (interactive)
| Item | Layer | Notes |
|------|-------|-------|
| `mise` activation | [general] | Exports the shared-config env **before** `mise activate` so tools like Go land on `PATH` (guarded on `/opt/mise/config.toml` existing) |
| History search keybindings | [general] | Up/Down arrows do prefix history search |
| History settings | [general] | Large `HISTSIZE`, timestamps, `HISTIGNORE` |
| `PATH` additions | [general] | Go (`~/go/bin`), Cargo (`~/.cargo/bin`), Krew |
| Terraform / Terragrunt plugin cache | [general] | `TF_PLUGIN_CACHE_DIR`, `TG_PROVIDER_CACHE` |
| `EDITOR` / `KUBE_EDITOR` = `vim` | [general] | |
| mosh env (`LOCPATH`, `LANG`, mosh `PATH`) | [general] | Prepended **above** the interactive guard in `~/.bashrc` so it reaches the non-interactive ssh shell `mosh-server` runs in |
| 1Password service-account token | [eng] | Sources `~/.op-sa.env` if present (token file lives in `$HOME`, never in this repo) |

### Shell functions
| Function | Layer | Purpose |
|----------|-------|---------|
| `refresh-creds` | [general] | Refresh AWS Pod-Identity + CodeArtifact creds in the current shell (relevant to any long-running workspace) |
| `connect_to_db <env>` | [eng] | Open `psql` against a database by short env name. The env->profile map, secret id, and DSN key are read from `~/.connect_to_db.env` (kept in `$HOME`, not committed), so no environment or target names live in this repo |

### Aliases ([general], see `aliases/custom.bash`)
`ll`, safe `rm`/`mv`/`cp` (`-i`), `vi`/`ex` -> vim, `gcd` (cd to git root), kubectl shortcuts
(`k`, `kgp`, `kgs`, `kgn`, `kns`, `kctx`), `py` -> python3, `uvr` -> uv run.

## Layout

```
CLAUDE.md               # agent guidance: keep this README in sync; preserve invariants
install.sh              # entrypoint Coder runs on every start (idempotent)
.bash_profile           # login shells source ~/.bashrc
.config/starship.toml   # prompt config
.config/zellij/         # zellij config.kdl + layouts/default.kdl (zellaude Claude Code bar)
aliases/custom.bash     # aliases (sourced for both bash and zsh)
custom/custom.bash      # general interactive bash config: env, keybindings, refresh-creds
engineering/            # engineering-only layer - delete for a general-purpose setup
  install.sh            #   gh bridge, observability MCP binaries, op (1Password) CLI
  shell.bash            #   op-sa.env sourcing, connect_to_db (symlinked into ~/.bash_it/custom/)
```

`install.sh` runs the general setup, then - only if `engineering/` exists and
`DOTFILES_NO_ENGINEERING` is unset - symlinks `engineering/shell.bash` into `~/.bash_it/custom/`
(bash-it auto-loads it) and sources `engineering/install.sh`.

> **Shell note:** this fork targets **bash**. Interactive config lives in `custom/custom.bash` and the
> engineering `shell.bash`, both loaded via bash-it's `custom/` dir; the zsh branch does not source
> them (zsh only sources `aliases/custom.bash`). Switching to zsh means porting those into the zsh path.

## Secrets & local config

No secrets - and no environment/target names - live in this repo. They are read from `0600` files kept
in `$HOME` (recreate these per workspace):

- `~/.op-sa.env` *(eng)* - 1Password service-account token
- `~/.codeartifact.env`, `~/.aws-pod-identity.env` - refreshed AWS/CodeArtifact creds
- `~/.connect_to_db.env` *(eng)* - the `connect_to_db` env->profile map, secret id, and DSN key. Format:

  ```bash
  CONNECT_DB_SECRET_ID="<secretsmanager-secret-id>"
  CONNECT_DB_DSN_KEY="<json-key-holding-the-dsn>"
  CONNECT_DB_PROFILES=( [envname]=awsprofile [other]=otherprofile )
  ```

## Maintenance

```bash
# edit, then:
git push                                   # over SSH (personal-account repos 403 over Coder HTTPS)
# restart a workspace to apply

# pull Core-team updates from the default dotfiles:
git fetch upstream && git merge upstream/main
```
