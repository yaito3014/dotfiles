# dotfiles

On a fresh Debian or Ubuntu machine:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/yaito3014/dotfiles/main/install.sh)"
```

This installs what is missing (git, zsh, chezmoi, mise, oh-my-posh), clones
this repository into `~/.local/share/dotfiles`, applies `home/` to `$HOME` with
[chezmoi](https://www.chezmoi.io) (moving files it would overwrite to
`~/.local/state/dotfiles/backup/`), makes zsh the login shell, and registers
this machine as a self-hosted runner of `yaito3014/ops`. Re-running it is safe.

After that, every push to `main` reaches each machine within seconds: the
`notify` workflow dispatches to `yaito3014/ops`, which runs a job on every
online runner that touches `/run/dotfiles-sync/trigger`, and
`dotfiles-sync.path` fast-forwards the clone and runs `chezmoi apply`. A
5-minute timer covers missed triggers.

Files are copies, so change them here and push rather than editing them in
`$HOME`. A file edited in place is left alone and fails the sync until
resolved: `chezmoi diff` shows the difference, and `chezmoi apply --force
<file>` discards the edit. `~/.claude/settings.json` is the exception: Claude
Code writes it, so its own keys are kept and only the keys in
`home/.chezmoitemplates/claude-settings.json` are overwritten.

Set `DOTFILES_RUNNER=0` to skip the runner (the timer still syncs), or
`DOTFILES_DIR` to apply from another clone.

## Windows

From an elevated PowerShell (or a normal one with `$env:DOTFILES_RUNNER = '0'`):

```powershell
irm https://raw.githubusercontent.com/yaito3014/dotfiles/main/install.ps1 | iex
```

This installs what is missing with winget (Git for Windows, jq, mise,
oh-my-posh) and chezmoi into `~\.local\bin`, applies the same files minus the
zsh, bash and systemd ones, adds a line to the PowerShell profiles that loads
`~\.config\powershell\profile.ps1`, and allows local scripts for the current
user so that profile can run. `apply.sh` and `dotfiles-sync` run under Git
Bash, which the Claude Code hook needs anyway.

Syncing works as on Linux: the runner service, as NETWORK SERVICE, writes
`C:\ProgramData\dotfiles-sync\trigger`, and the `dotfiles-sync` scheduled
task, started at logon as the user, runs `dotfiles-sync` when that file changes
and at least every 5 minutes, logging to `~\.local\state\dotfiles\sync.log`.
