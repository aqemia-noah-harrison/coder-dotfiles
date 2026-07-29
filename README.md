# coder-dotfiles

Personal [Coder](https://coder.com) workspace dotfiles for **Noah Harrison**, forked from
[`Aqemia/coder-default-dotfiles`](https://github.com/Aqemia/coder-default-dotfiles) and extended
with the tools and shell config previously carried in `~/personalize`.

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

Legend: **[base]** = inherited from `coder-default-dotfiles`; **[mine]** = added in this fork.
Tools marked *(configures)* are already present in the workspace image; the dotfiles only wire them up.

### Shell framework & prompt
| Item | Source | Notes |
|------|--------|-------|
| **bash-it** | [base] | Installed to `~/.bash_it`; theme `pure`, with completions (git, docker, kubectl, terraform, gh, go) and the base plugin |
| **zsh plugins** | [base] | `zsh-autosuggestions` + `zsh-syntax-highlighting` (only when `PREFERRED_SHELL=zsh`) |
| **starship** *(configures)* | [base] | Prompt; k8s segment enabled, aws/gcloud/container segments disabled (see `.config/starship.toml`) |
| **zoxide** *(configures)* | [base] | Smart `cd` |
| Interactive guard in `~/.bashrc` | [base] | Early-returns for non-interactive shells so sshd-spawned shells behave |

### CLI tools installed
| Tool | Source | Where | Purpose |
|------|--------|-------|---------|
| **mcp-victoriametrics** | [mine] | `~/.local/bin` | observability-core plugin MCP (metrics) |
| **mcp-victorialogs** | [mine] | `~/.local/bin` | observability-core plugin MCP (logs) |
| **mcp-grafana** | [mine] | `~/.local/bin` | observability-core plugin MCP (Grafana) |
| **op** (1Password CLI) | [mine] | `~/.local/bin` | Secret retrieval |
| **zellij** *(via mise)* | [mine] | mise global | Terminal multiplexer |
| **mosh-server** | [mine] | `~/.local/mosh` | Roaming SSH; conda-forge build (no root needed) |
| **UTF-8 locales** | [mine] | `~/.locale` | `en_GB.UTF-8` / `en_US.UTF-8` compiled with `localedef` (mosh needs a resolvable UTF-8 locale) |

`gh` is also bridged to the Coder git token at install time so `gh release download` (used to fetch the
MCP binaries) is authenticated rather than anonymous/rate-limited.

### Shell environment (interactive)
| Item | Source | Notes |
|------|--------|-------|
| `1Password service-account token` | [mine] | Sources `~/.op-sa.env` if present (the token file lives in `$HOME`, never in this repo) |
| `mise` activation | [mine] | Exports `MISE_GLOBAL_CONFIG_FILE` / `MISE_DATA_DIR` **before** `mise activate` so tools like Go land on `PATH` |
| History search keybindings | [mine] | Up/Down arrows do prefix history search |
| History settings | [base] | Large `HISTSIZE`, timestamps, `HISTIGNORE` |
| `PATH` additions | [base] | Go (`~/go/bin`), Cargo (`~/.cargo/bin`), Krew |
| Terraform / Terragrunt plugin cache | [base] | `TF_PLUGIN_CACHE_DIR`, `TG_PROVIDER_CACHE` |
| `EDITOR` / `KUBE_EDITOR` = `vim` | [base] | |
| mosh env (`LOCPATH`, `LANG`, mosh `PATH`) | [mine] | Prepended **above** the interactive guard in `~/.bashrc` so it reaches the non-interactive ssh shell `mosh-server` runs in |

### Shell functions
| Function | Source | Purpose |
|----------|--------|---------|
| `connect_to_db <env>` | [mine] | Open `psql` against a database by short env name. The env->profile map, Secrets Manager secret id, and DSN key are read from `~/.connect_to_db.env` (kept in `$HOME`, not committed), so no environment or target names live in this repo |
| `refresh-creds` | [mine] | Refresh AWS Pod-Identity + CodeArtifact creds in the current shell |

### Aliases ([base], see `aliases/custom.bash`)
`ll`, safe `rm`/`mv`/`cp` (`-i`), `vi`/`ex` -> vim, `gcd` (cd to git root), kubectl shortcuts
(`k`, `kgp`, `kgs`, `kgn`, `kns`, `kctx`), `py` -> python3, `uvr` -> uv run.

## Layout

```
install.sh            # entrypoint Coder runs on every start (idempotent)
.bash_profile         # login shells source ~/.bashrc
.config/starship.toml # prompt config
aliases/custom.bash   # aliases (sourced for both bash and zsh)
custom/custom.bash    # interactive bash config: env, functions, keybindings (bash only)
```

> **Shell note:** this fork targets **bash**. The interactive additions live in `custom/custom.bash`,
> which the zsh branch does not source (zsh only sources `aliases/custom.bash`). If you switch to zsh,
> those functions/env need porting into the zsh path.

## Secrets

No secrets - and no environment/target names - live in this repo. They are read from `0600` files
kept in `$HOME` (recreate these per workspace):

- `~/.op-sa.env` - 1Password service-account token
- `~/.codeartifact.env`, `~/.aws-pod-identity.env` - refreshed AWS/CodeArtifact creds
- `~/.connect_to_db.env` - the `connect_to_db` env->profile map, secret id, and DSN key. Format:

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
