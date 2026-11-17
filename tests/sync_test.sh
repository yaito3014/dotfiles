#!/bin/sh
# Tests for dotfiles-sync against a local origin whose link.sh and systemctl
# are stubs that only record that they ran. Each run goes through a link in
# $HOME/.local/bin into the clone, as stow installs it.
set -eu

repo=$(cd -P "$(dirname "$0")/.." && pwd)
sync=$repo/dotfiles-sync/dot-local/bin/dotfiles-sync
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
failures=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

export HOME="$scratch/home" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
mkdir -p "$HOME/.local/bin" "$scratch/bin"
log=$scratch/log

cat >"$scratch/bin/systemctl" <<EOF
#!/bin/sh
echo "systemctl \$*" >>"$log"
EOF
chmod +x "$scratch/bin/systemctl"
PATH="$scratch/bin:$PATH"

work=$scratch/work
git init -q -b main "$work"
cat >"$work/link.sh" <<EOF
#!/bin/sh
echo link >>"$log"
EOF
chmod +x "$work/link.sh"
mkdir -p "$work/dotfiles-sync/dot-local/bin"
cp "$sync" "$work/dotfiles-sync/dot-local/bin/"
git -C "$work" add .
git -C "$work" commit -q -m init
git clone -q --bare "$work" "$scratch/origin.git"
git -C "$work" remote add origin "$scratch/origin.git"

push_change() {
    echo "$1" >"$work/file"
    git -C "$work" add file
    git -C "$work" commit -q -m "$1"
    git -C "$work" push -q origin main
}

new_deploy() {
    d=$(mktemp -d "$scratch/deploy.XXXXXX")
    rmdir "$d"
    git clone -q "$scratch/origin.git" "$d"
    echo "$d"
}

run_sync() {
    : >"$log"
    ln -sfn "$1/dotfiles-sync/dot-local/bin/dotfiles-sync" \
        "$HOME/.local/bin/dotfiles-sync"
    "$HOME/.local/bin/dotfiles-sync" >/dev/null 2>&1
}

d=$(new_deploy)
run_sync "$d" || fail "up to date: exited non-zero"
[ ! -s "$log" ] || fail "up to date: ran $(cat "$log")"

d=$(new_deploy)
push_change one
run_sync "$d" || fail "behind: exited non-zero"
[ "$(git -C "$d" rev-parse HEAD)" = "$(git -C "$work" rev-parse HEAD)" ] ||
    fail "behind: did not fast-forward"
grep -qx link "$log" || fail "behind: did not run link.sh"
grep -qx 'systemctl --user daemon-reload' "$log" ||
    fail "behind: did not reload user units"

d=$(new_deploy)
push_change two
echo local >"$d/file"
if run_sync "$d"; then fail "dirty: exited zero"; fi
[ "$(cat "$d/file")" = local ] || fail "dirty: overwrote local changes"
[ ! -s "$log" ] || fail "dirty: ran $(cat "$log")"

d=$(new_deploy)
push_change three
git -C "$d" switch -q -c topic
if run_sync "$d"; then fail "other branch: exited zero"; fi
[ "$(git -C "$d" branch --show-current)" = topic ] ||
    fail "other branch: switched branches"
[ ! -s "$log" ] || fail "other branch: ran $(cat "$log")"

# Follows its link to the clone, whatever DOTFILES_DIR says.
d=$(new_deploy)
push_change four
(export DOTFILES_DIR="$scratch/elsewhere" && run_sync "$d") ||
    fail "linked clone: exited non-zero"
[ "$(git -C "$d" rev-parse HEAD)" = "$(git -C "$work" rev-parse HEAD)" ] ||
    fail "linked clone: did not fast-forward"

lone=$scratch/lone
mkdir -p "$lone/dotfiles-sync/dot-local/bin"
cp "$sync" "$lone/dotfiles-sync/dot-local/bin/"
if run_sync "$lone"; then fail "not a clone: exited zero"; fi

[ "$failures" -eq 0 ] || exit 1
echo "sync_test: ok"
