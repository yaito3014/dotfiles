#!/bin/sh
# Link every stow package in this repository into $HOME. Anything already in
# the way is moved to a timestamped backup first, so stow never conflicts.
set -eu

repo=$(cd -P "$(dirname "$0")" && pwd)
backup="$HOME/.local/state/dotfiles/backup/$(date +%Y%m%dT%H%M%S)"

is_package() {
    case $1 in
    tests) return 1 ;;
    *) return 0 ;;
    esac
}

move_aside() {
    mkdir -p "$backup/$(dirname "$1")"
    mv "$HOME/$1" "$backup/$1"
    printf 'moved ~/%s to %s\n' "$1" "$backup/$1"
}

# A symlinked ancestor (e.g. a directory stow folded earlier) is moved aside
# as a whole: moving the file through it would modify wherever it points.
clear_path() {
    prefix=
    rest=$1
    while :; do
        case $rest in */*) ;; *) break ;; esac
        prefix=${prefix:+$prefix/}${rest%%/*}
        rest=${rest#*/}
        if [ -L "$HOME/$prefix" ]; then
            move_aside "$prefix"
            return
        fi
    done
    if [ -L "$HOME/$1" ] || [ -e "$HOME/$1" ]; then
        [ "$(readlink -f "$HOME/$1")" = "$(readlink -f "$2")" ] ||
            move_aside "$1"
    fi
}

set --
for path in "$repo"/*/; do
    package=$(basename "$path")
    is_package "$package" || continue
    set -- "$@" "$package"
    (cd "$repo/$package" && find . \( -type f -o -type l \) -print) |
        while IFS= read -r file; do
            file=${file#./}
            target=$(printf '%s\n' "$file" | sed -e 's|^dot-|.|' -e 's|/dot-|/.|g')
            clear_path "$target" "$repo/$package/$file"
        done
done

stow --dotfiles --no-folding --restow --dir "$repo" --target "$HOME" "$@"
