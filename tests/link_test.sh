#!/bin/sh
# Tests for the link.sh migration stub, as the stow-era dotfiles-sync calls it
# after fast-forwarding: a stale stow link in a throwaway HOME, with chezmoi
# already in ~/.local/bin so nothing is downloaded.
set -eu

repo=$(cd -P "$(dirname "$0")/.." && pwd)
case $(uname -s) in
MINGW* | MSYS*)
    echo "link_test: skipped (no stow-era machines on Windows)"
    exit 0
    ;;
esac
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
failures=0
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

mkdir -p "$scratch/bin"
printf '#!/bin/sh\n' >"$scratch/bin/systemctl"
chmod +x "$scratch/bin/systemctl"

HOME=$scratch/home
mkdir -p "$HOME/.local/bin"
ln -s "$(command -v chezmoi)" "$HOME/.local/bin/chezmoi"
ln -s "$repo/zsh/dot-zshrc" "$HOME/.zshrc"
(cd "$repo" && PATH="$scratch/bin:/usr/bin:/bin" ./link.sh >/dev/null) ||
    fail "exited non-zero"
{ [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ] &&
    cmp -s "$HOME/.zshrc" "$repo/home/dot_zshrc"; } ||
    fail "the stale stow link was not replaced by the applied file"
[ -n "$(find "$HOME/.local/state/dotfiles/backup" -name .zshrc 2>/dev/null)" ] ||
    fail "the stale stow link was not backed up"

[ "$failures" -eq 0 ] || exit 1
echo "link_test: ok"
