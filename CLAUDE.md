# Repository guidance for agents

`README.md` is the human-facing source of truth for **everything these dotfiles
install and configure**. It must never drift from what the scripts actually do.

## Always update the README in the same change

Whenever you change what the dotfiles do, update `README.md` as part of the same
commit. In particular:

- Add / remove / change a tool installed by `install.sh` or
  `engineering/install.sh` -> update the "CLI tools installed" table.
- Add / change a shell function, alias, env var, or keybinding in
  `custom/custom.bash`, `aliases/custom.bash`, or `engineering/shell.bash` ->
  update the relevant "Shell ..." table.
- Add / change a config file (e.g. under `.config/`) -> update the tables and the
  "Layout" section.
- Move something between the general and engineering layers -> update its
  `[general]` / `[eng]` tag and any layer notes.
- Add a new `$HOME` file that a feature reads (secret or config) -> update the
  "Secrets & local config" section.

## Invariants to preserve

- **Idempotent installs.** `install.sh` and `engineering/install.sh` run on every
  Coder workspace start - guard every step so re-running is safe.
- **No secrets or environment/target names in the repo.** They live in `0600`
  files under `$HOME` and are only sourced if present (e.g. `~/.op-sa.env`,
  `~/.connect_to_db.env`). The repo is public.
- **Keep the general vs engineering split clean.** Engineering-only tooling lives
  under `engineering/` and is gated on that directory existing; deleting the
  directory must still leave a working general-purpose setup.
- **Targets bash.** Interactive config is loaded via bash-it's `custom/` dir; the
  zsh branch only sources `aliases/custom.bash`.
