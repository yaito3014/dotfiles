#!/bin/sh
# Migration stub for machines still running the stow-era dotfiles-sync, which
# fast-forwards the clone and then runs ./link.sh: install chezmoi and apply
# the clone, replacing the stale stow links. Delete once no machine syncs with
# the stow-era script (YK-VIVO is the last one known).
set -eu

repo=$(cd -P "$(dirname "$0")" && pwd)
bin=$HOME/.local/bin
if [ ! -x "$bin/chezmoi" ]; then
    mkdir -p "$bin"
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$bin"
fi
PATH=$bin:$PATH "$repo/apply.sh"
