#!/bin/sh
# Tests for apply.sh, each against a throwaway HOME, with a systemctl stub that
# only records its calls so no real user manager is touched.
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

mkdir -p "$scratch/bin"
log=$scratch/systemctl.log
printf '#!/bin/sh\necho "$*" >>"%s"\n' "$log" >"$scratch/bin/systemctl"
chmod +x "$scratch/bin/systemctl"
PATH="$scratch/bin:$PATH"

new_home() {
    mktemp -d "$scratch/home.XXXXXX"
}

run_apply() {
    HOME=$1 "$repo/apply.sh" >/dev/null
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
applied "$h" .zshrc home/dot_zshrc || fail "fresh: ~/.zshrc is not applied"
for f in .codex/AGENTS.md .gemini/GEMINI.md .copilot/copilot-instructions.md; do
    applied "$h" "$f" home/dot_claude/CLAUDE.md ||
        fail "fresh: ~/$f is not a copy of CLAUDE.md"
done
[ -x "$h/.claude/hooks/self-review.sh" ] || fail "fresh: hook is not executable"
[ "$(HOME=$h chezmoi source-path)" = "$repo/home" ] ||
    fail "fresh: chezmoi does not use this clone as its source"
[ ! -e "$h/.local/state/dotfiles/backup" ] || fail "fresh: made a backup"

h=$(new_home)
printf 'old\n' >"$h/.zshrc"
run_apply "$h"
applied "$h" .zshrc home/dot_zshrc || fail "regular file: ~/.zshrc is not applied"
b=$(backup_of "$h" .zshrc)
{ [ -f "$b" ] && [ "$(cat "$b")" = old ]; } ||
    fail "regular file: old ~/.zshrc was not backed up"

h=$(new_home)
mkdir -p "$h/.config/git"
printf 'old\n' >"$h/.config/git/config"
run_apply "$h"
applied "$h" .config/git/config home/dot_config/git/config ||
    fail "nested file: ~/.config/git/config is not applied"
[ -f "$(backup_of "$h" .config/git/config)" ] ||
    fail "nested file: old ~/.config/git/config was not backed up"

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
grep -qx -- '--user daemon-reload' "$log" ||
    fail "units: did not reload user units on the first apply"
: >"$log"
run_apply "$h"
applied "$h" .zshrc home/dot_zshrc || fail "rerun: ~/.zshrc is not applied"
[ ! -e "$h/.local/state/dotfiles/backup" ] || fail "rerun: made a backup"
! grep -q daemon-reload "$log" || fail "rerun: reloaded unchanged user units"

[ "$failures" -eq 0 ] || exit 1
echo "apply_test: ok"
