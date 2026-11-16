# dotfiles

On a fresh Debian or Ubuntu machine:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/yaito3014/dotfiles/main/install.sh)"
```

This installs what is missing (git, stow, zsh, mise, oh-my-posh), clones this
repository into `~/.local/share/dotfiles`, links every package into `$HOME`
(moving conflicting files to `~/.local/state/dotfiles/backup/`), makes zsh the
login shell, and registers this machine as a self-hosted runner of
`yaito3014/ops`. Re-running it is safe.

After that, every push to `main` reaches each machine within seconds: the
`notify` workflow dispatches to `yaito3014/ops`, which runs a job on every
online runner that touches `/run/dotfiles-sync/trigger`, and
`dotfiles-sync.path` fast-forwards the clone and relinks. A 5-minute timer
covers missed triggers.

Set `DOTFILES_RUNNER=0` to skip the runner (the timer still syncs), or
`DOTFILES_DIR` to link from another clone.
