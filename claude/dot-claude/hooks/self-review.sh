#!/bin/sh
# Claude Code hook that makes the agent review its own changes before it ends
# a turn that modified files. Wired up in ../settings.json:
#   begin  UserPromptSubmit: reset state, snapshot git
#   mark   PostToolUse on Edit|Write|NotebookEdit: record a file-tool edit
#   check  Stop: block once if the turn changed files
#   end    SessionEnd: remove the session's state
set -eu

case ${1-} in
begin | mark | check | end) ;;
*)
  echo "usage: self-review.sh begin|mark|check|end" >&2
  exit 2
  ;;
esac

input=$(cat)

field() {
  printf '%s' "$input" | jq -r "$1 // empty"
}

session=$(field .session_id)
[ -n "$session" ] || exit 0
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/claude-self-review
mkdir -p "$state_dir"
marker=$state_dir/$session.edited
snapshot=$state_dir/$session.git

# Shell commands can edit files without going through the file tools, so the
# git state of the working directory is compared against the turn's start too.
git_state() {
  cwd=$(field .cwd)
  { [ -n "$cwd" ] && cd "$cwd" 2>/dev/null; } || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  {
    git rev-parse HEAD 2>/dev/null || :
    git status --porcelain=v1 --untracked-files=all
    git diff HEAD --binary 2>/dev/null || :
    git ls-files --others --exclude-standard |
      git hash-object --stdin-paths 2>/dev/null || :
  } | git hash-object --stdin
}

reset() {
  rm -f "$marker"
  git_state >"$snapshot"
}

case ${1-} in
begin)
  reset
  ;;
mark)
  : >"$marker"
  ;;
check)
  # Set when this stop follows a continuation forced by a Stop hook: the
  # review already ran, so let the turn end instead of looping.
  if [ "$(field .stop_hook_active)" = true ]; then
    reset
    exit 0
  fi
  changed=false
  [ -e "$marker" ] && changed=true
  if [ "$changed" = false ] && [ -e "$snapshot" ] &&
    [ "$(git_state)" != "$(cat "$snapshot")" ]; then
    changed=true
  fi
  [ "$changed" = true ] || exit 0
  reset
  jq -n '{
    decision: "block",
    reason: "You changed files in this turn. Before reporting done, review your own changes: re-read the full diff of everything you changed (uncommitted changes, commits made this turn, and new or non-git files), not just the edited lines. Check the surrounding code for inconsistencies the change introduced, stray edits, debug output, and scope creep, and sweep for other instances of the same class of issue and the edge cases the change touches. Fix what you find, then finish with a brief note on what the review found (one line if nothing)."
  }'
  ;;
end)
  rm -f "$marker" "$snapshot"
  ;;
esac
