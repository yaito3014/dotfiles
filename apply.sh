#!/bin/sh
# Make this clone chezmoi's source and apply it to $HOME. Anything chezmoi
# would overwrite is moved to a timestamped backup first: chezmoi itself only
# guards files it has written before.
set -eu

repo=$(cd -P "$(dirname "$0")" && pwd)
backup="$HOME/.local/state/dotfiles/backup/$(date +%Y%m%dT%H%M%S)"

move_aside() {
    mkdir -p "$backup/$(dirname "$1")"
    mv "$HOME/$1" "$backup/$1"
    printf 'moved ~/%s to %s\n' "$1" "$backup/$1"
}

config=${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi
mkdir -p "$config"
printf "sourceDir = '%s'\n" "$repo" >"$config/chezmoi.toml"

status=$(chezmoi status)
printf '%s\n' "$status" | while IFS= read -r line; do
    # The second column is how the target differs from what chezmoi would write.
    [ "$(printf '%s\n' "$line" | cut -c2)" = M ] || continue
    target=$(printf '%s\n' "$line" | cut -c4-)
    # Real directories are kept; a path may also be gone because a symlinked
    # parent was already moved aside.
    { [ -L "$HOME/$target" ] || [ -f "$HOME/$target" ]; } || continue
    # Files merged in place (modify_) build on what is there.
    case $(basename "$(chezmoi source-path "$HOME/$target")") in
    modify_*) continue ;;
    esac
    move_aside "$target"
done
chezmoi apply --no-tty --error-on-conflict
