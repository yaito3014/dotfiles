#!/bin/sh
# Tests for link.sh, each against a throwaway HOME.
set -eu

repo=$(cd -P "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
failures=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

new_home() {
    mktemp -d "$scratch/home.XXXXXX"
}

run_link() {
    HOME=$1 "$repo/link.sh" >/dev/null
}

linked() {
    [ -L "$1/$2" ] && [ "$(readlink -f "$1/$2")" = "$repo/$3" ]
}

backup_of() {
    find "$1/.local/state/dotfiles/backup" -path "*/$2" 2>/dev/null
}

h=$(new_home)
run_link "$h"
linked "$h" .zshrc zsh/dot-zshrc || fail "fresh: ~/.zshrc is not linked"
linked "$h" .claude/CLAUDE.md claude/dot-claude/CLAUDE.md ||
    fail "fresh: ~/.claude/CLAUDE.md is not linked"
{ [ -d "$h/.claude" ] && [ ! -L "$h/.claude" ]; } ||
    fail "fresh: ~/.claude was folded into a symlink"
[ ! -e "$h/link_test.sh" ] || fail "fresh: tests/ was linked as a package"
[ ! -e "$h/.local/state/dotfiles/backup" ] || fail "fresh: made a backup"

h=$(new_home)
printf 'old\n' >"$h/.zshrc"
run_link "$h"
linked "$h" .zshrc zsh/dot-zshrc || fail "regular file: ~/.zshrc is not linked"
b=$(backup_of "$h" .zshrc)
{ [ -f "$b" ] && [ "$(cat "$b")" = old ]; } ||
    fail "regular file: old ~/.zshrc was not backed up"

h=$(new_home)
mkdir -p "$h/.config/git"
printf 'old\n' >"$h/.config/git/config"
run_link "$h"
linked "$h" .config/git/config git/dot-config/git/config ||
    fail "nested file: ~/.config/git/config is not linked"
[ -f "$(backup_of "$h" .config/git/config)" ] ||
    fail "nested file: old ~/.config/git/config was not backed up"

h=$(new_home)
ln -s /nonexistent "$h/.bashrc"
run_link "$h"
linked "$h" .bashrc bash/dot-bashrc || fail "foreign link: ~/.bashrc is not linked"
[ -L "$(backup_of "$h" .bashrc)" ] ||
    fail "foreign link: old ~/.bashrc link was not backed up"

h=$(new_home)
other=$(mktemp -d "$scratch/other.XXXXXX")
printf 'theirs\n' >"$other/config.toml"
ln -s "$other" "$h/.oh-my-posh"
run_link "$h"
linked "$h" .oh-my-posh/config.toml zsh/dot-oh-my-posh/config.toml ||
    fail "folded dir: ~/.oh-my-posh/config.toml is not linked"
[ "$(cat "$other/config.toml" 2>/dev/null)" = theirs ] ||
    fail "folded dir: moved a file out of the directory the old link pointed to"
[ -L "$(backup_of "$h" .oh-my-posh)" ] ||
    fail "folded dir: old ~/.oh-my-posh link was not backed up"

h=$(new_home)
run_link "$h"
run_link "$h"
linked "$h" .zshrc zsh/dot-zshrc || fail "rerun: ~/.zshrc is not linked"
[ ! -e "$h/.local/state/dotfiles/backup" ] || fail "rerun: made a backup"

[ "$failures" -eq 0 ] || exit 1
echo "link_test: ok"
