#!/bin/sh
# Tests for dotfiles-sync against a local origin holding a small chezmoi
# source, each case with its own HOME and deploy clone.
set -eu

repo=$(cd -P "$(dirname "$0")/.." && pwd)
sync=$repo/home/dot_local/bin/executable_dotfiles-sync
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
failures=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

work=$scratch/work
git init -q -b main "$work"
mkdir "$work/home"
echo home >"$work/.chezmoiroot"
echo one >"$work/home/dot_file"
echo one >"$work/home/dot_other"
git -C "$work" add .
git -C "$work" commit -q -m init
git clone -q --bare "$work" "$scratch/origin.git"
git -C "$work" remote add origin "$scratch/origin.git"

# Commit $2 as the contents of home/dot_$1 and push it.
push_change() {
    echo "$2" >"$work/home/dot_$1"
    git -C "$work" commit -q -am "$1: $2"
    git -C "$work" push -q origin main
}

# Start a case: a fresh HOME whose chezmoi source is a new clone, $d.
new_case() {
    HOME=$(mktemp -d "$scratch/home.XXXXXX")
    d=$HOME/source
    git clone -q "$scratch/origin.git" "$d"
    mkdir -p "$HOME/.config/chezmoi"
    printf "sourceDir = '%s'\n" "$d" >"$HOME/.config/chezmoi/chezmoi.toml"
}

run_sync() {
    "$sync" >/dev/null 2>&1
}

new_case
run_sync || fail "up to date: exited non-zero"
[ "$(cat "$HOME/.file" 2>/dev/null)" = one ] || fail "up to date: did not apply"

new_case
push_change file two
run_sync || fail "behind: exited non-zero"
[ "$(git -C "$d" rev-parse HEAD)" = "$(git -C "$work" rev-parse HEAD)" ] ||
    fail "behind: did not fast-forward"
[ "$(cat "$HOME/.file" 2>/dev/null)" = two ] || fail "behind: did not apply"

new_case
push_change file three
echo local >"$d/home/dot_file"
if run_sync; then fail "dirty: exited zero"; fi
[ "$(cat "$d/home/dot_file")" = local ] || fail "dirty: overwrote local changes"
[ ! -e "$HOME/.file" ] || fail "dirty: applied"

new_case
push_change file four
git -C "$d" switch -q -c topic
if run_sync; then fail "other branch: exited zero"; fi
[ "$(git -C "$d" branch --show-current)" = topic ] ||
    fail "other branch: switched branches"
[ ! -e "$HOME/.file" ] || fail "other branch: applied"

new_case
run_sync || fail "edited target: setup exited non-zero"
echo edited >"$HOME/.file"
push_change other five
if run_sync; then fail "edited target: exited zero"; fi
[ "$(cat "$HOME/.file")" = edited ] || fail "edited target: overwrote the edit"
[ "$(cat "$HOME/.other" 2>/dev/null)" = five ] ||
    fail "edited target: did not apply the other files"

new_case
rm -rf "$d"
if run_sync; then fail "missing clone: exited zero"; fi

[ "$failures" -eq 0 ] || exit 1
echo "sync_test: ok"
