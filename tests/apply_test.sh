#!/bin/sh
# Tests for apply.sh, each against a throwaway HOME, with a systemctl stub that
# only records its calls so no real user manager is touched. Also runs under
# Git Bash on Windows, where the symlink and systemd cases do not apply.
set -eu

repo=$(cd -P "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
failures=0

# chezmoi keeps its config and state under these when set (CI sets
# XDG_CONFIG_HOME), so only HOME may decide where they go.
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

case $(uname -s) in
MINGW* | MSYS*) windows=true ;;
*) windows=false ;;
esac

mkdir -p "$scratch/bin"
log=$scratch/systemctl.log
printf '#!/bin/sh\necho "$*" >>"%s"\n' "$log" >"$scratch/bin/systemctl"
chmod +x "$scratch/bin/systemctl"
PATH="$scratch/bin:$PATH"

new_home() {
    mktemp -d "$scratch/home.XXXXXX"
}

# Run the rest of the arguments with HOME $1; chezmoi on Windows takes its
# home from USERPROFILE instead.
with_home() {
    home_dir=$1
    shift
    if $windows; then
        HOME=$home_dir USERPROFILE=$(cygpath -w "$home_dir") "$@"
    else
        HOME=$home_dir "$@"
    fi
}

run_apply() {
    with_home "$1" "$repo/apply.sh" >/dev/null
}

# $2 is a regular file in HOME $1 with the contents of $3 in the repository.
applied() {
    [ -f "$1/$2" ] && [ ! -L "$1/$2" ] && cmp -s "$1/$2" "$repo/$3"
}

backup_of() {
    find "$1/.local/state/dotfiles/backup" -path "*/$2" 2>/dev/null
}

h=$(new_home)
run_apply "$h"
applied "$h" .claude/CLAUDE.md home/dot_claude/CLAUDE.md ||
    fail "fresh: ~/.claude/CLAUDE.md is not applied"
for f in .codex/AGENTS.md .gemini/GEMINI.md .copilot/copilot-instructions.md; do
    applied "$h" "$f" home/dot_claude/CLAUDE.md ||
        fail "fresh: ~/$f is not a copy of CLAUDE.md"
done
[ -x "$h/.claude/hooks/self-review.sh" ] || fail "fresh: hook is not executable"
applied "$h" .local/bin/dotfiles-sync home/dot_local/bin/executable_dotfiles-sync ||
    fail "fresh: dotfiles-sync is not applied"
[ "$(cd "$(with_home "$h" chezmoi source-path)" && pwd -P)" = "$repo/home" ] ||
    fail "fresh: chezmoi does not use this clone as its source"
if $windows; then
    applied "$h" .config/powershell/profile.ps1 home/dot_config/powershell/profile.ps1 ||
        fail "fresh: the PowerShell profile is not applied"
    for f in .zshrc .bashrc .config/systemd; do
        [ ! -e "$h/$f" ] || fail "fresh: applied ~/$f on Windows"
    done
else
    applied "$h" .zshrc home/dot_zshrc || fail "fresh: ~/.zshrc is not applied"
    for f in .config/powershell .local/bin/dotfiles-sync-watch.ps1; do
        [ ! -e "$h/$f" ] || fail "fresh: applied ~/$f outside Windows"
    done
fi
[ ! -e "$h/.local/state/dotfiles/backup" ] || fail "fresh: made a backup"

h=$(new_home)
mkdir -p "$h/.claude"
printf 'old\n' >"$h/.claude/CLAUDE.md"
run_apply "$h"
applied "$h" .claude/CLAUDE.md home/dot_claude/CLAUDE.md ||
    fail "regular file: ~/.claude/CLAUDE.md is not applied"
b=$(backup_of "$h" .claude/CLAUDE.md)
{ [ -f "$b" ] && [ "$(cat "$b")" = old ]; } ||
    fail "regular file: old ~/.claude/CLAUDE.md was not backed up"

h=$(new_home)
mkdir -p "$h/.config/git"
printf 'old\n' >"$h/.config/git/config"
run_apply "$h"
applied "$h" .config/git/config home/dot_config/git/config ||
    fail "nested file: ~/.config/git/config is not applied"
[ -f "$(backup_of "$h" .config/git/config)" ] ||
    fail "nested file: old ~/.config/git/config was not backed up"

# Git Bash's ln copies instead of linking unless told otherwise, so these only
# mean something elsewhere.
if ! $windows; then
    h=$(new_home)
    ln -s /nonexistent "$h/.bashrc"
    run_apply "$h"
    applied "$h" .bashrc home/dot_bashrc || fail "foreign link: ~/.bashrc is not applied"
    [ -L "$(backup_of "$h" .bashrc)" ] ||
        fail "foreign link: old ~/.bashrc link was not backed up"

    h=$(new_home)
    other=$(mktemp -d "$scratch/other.XXXXXX")
    printf 'theirs\n' >"$other/config.toml"
    ln -s "$other" "$h/.oh-my-posh"
    run_apply "$h"
    applied "$h" .oh-my-posh/config.toml home/dot_oh-my-posh/config.toml ||
        fail "folded dir: ~/.oh-my-posh/config.toml is not applied"
    [ "$(cat "$other/config.toml" 2>/dev/null)" = theirs ] ||
        fail "folded dir: changed the directory the old link pointed to"
    [ -L "$(backup_of "$h" .oh-my-posh)" ] ||
        fail "folded dir: old ~/.oh-my-posh link was not backed up"
fi

# Modes must not depend on the umask of whoever applies (a login shell and
# the sync service may differ); Windows has no such modes.
if ! $windows; then
    h=$(new_home)
    (umask 002 && run_apply "$h")
    [ "$(stat -c %a "$h/.claude/CLAUDE.md")" = 644 ] ||
        fail "umask: applied ~/.claude/CLAUDE.md with the caller's umask"
    [ "$(stat -c %a "$h/.local/bin/dotfiles-sync")" = 755 ] ||
        fail "umask: applied ~/.local/bin/dotfiles-sync with the caller's umask"
fi

h=$(new_home)
mkdir -p "$h/.claude"
printf '{"hooks": {}, "fromApp": true}\n' >"$h/.claude/settings.json"
run_apply "$h"
grep -q '"fromApp": true' "$h/.claude/settings.json" ||
    fail "settings: dropped a key the app wrote"
grep -q 'self-review.sh' "$h/.claude/settings.json" ||
    fail "settings: did not apply the repository's hooks"
[ ! -e "$h/.local/state/dotfiles/backup" ] || fail "settings: made a backup"

h=$(new_home)
: >"$log"
run_apply "$h"
if $windows; then
    [ ! -s "$log" ] || fail "units: ran systemctl on Windows"
else
    grep -qx -- '--user daemon-reload' "$log" ||
        fail "units: did not reload user units on the first apply"
fi
: >"$log"
run_apply "$h"
applied "$h" .claude/CLAUDE.md home/dot_claude/CLAUDE.md ||
    fail "rerun: ~/.claude/CLAUDE.md is not applied"
[ ! -e "$h/.local/state/dotfiles/backup" ] || fail "rerun: made a backup"
! grep -q daemon-reload "$log" || fail "rerun: reloaded unchanged user units"

[ "$failures" -eq 0 ] || exit 1
echo "apply_test: ok"
