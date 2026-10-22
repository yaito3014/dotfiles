#!/usr/bin/env bash
# Install dependencies and symlink every stow package in this repo into $HOME.
# Existing files that would conflict are moved to a timestamped backup dir.
set -euo pipefail

DOTFILES=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DEPS=(git stow zsh curl unzip)

info() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "need root to run '$*', and sudo is not available"
  fi
}

install_packages() {
  local missing=() dep
  for dep in "${DEPS[@]}"; do
    command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
  done
  [ "${#missing[@]}" -eq 0 ] && return

  info "Installing packages: ${missing[*]}"
  if command -v brew >/dev/null 2>&1; then
    brew install "${missing[@]}"
  elif command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update
    as_root apt-get install -y "${missing[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    as_root dnf install -y "${missing[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    as_root pacman -S --needed --noconfirm "${missing[@]}"
  else
    die "no supported package manager found; install manually: ${missing[*]}"
  fi
}

install_oh_my_posh() {
  # .zshrc puts ~/.local/bin on PATH, so that is where the binary goes.
  local bin_dir="$HOME/.local/bin"
  if command -v oh-my-posh >/dev/null 2>&1 || [ -x "$bin_dir/oh-my-posh" ]; then
    return
  fi
  info "Installing oh-my-posh into $bin_dir"
  mkdir -p "$bin_dir"
  curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$bin_dir"
}

backup() {
  local target=$1 rel=$2
  mkdir -p "$(dirname -- "$BACKUP_DIR/$rel")"
  mv -- "$target" "$BACKUP_DIR/$rel"
  info "Backed up ~/$rel"
}

# Walk a package tree the way stow does and move aside anything in $HOME that
# would block it. Real directories are merged into (stow links inside them),
# except git submodules, which are replaced as a whole so that an unrelated
# checkout (e.g. a standalone oh-my-zsh install) is not left half-linked.
clear_conflicts() {
  local src_dir=$1 rel_dir=$2 src name rel target
  for src in "$src_dir"/.[!.]* "$src_dir"/..?* "$src_dir"/*; do
    [ -e "$src" ] || [ -L "$src" ] || continue
    name=${src##*/}
    [ "$name" = .git ] && continue
    rel=${rel_dir:+$rel_dir/}$name
    target="$HOME/$rel"

    if [ -L "$target" ]; then
      [ "$target" -ef "$src" ] || backup "$target" "$rel"
    elif [ -d "$target" ] && [ -d "$src" ] && [ ! -e "$src/.git" ]; then
      clear_conflicts "$src" "$rel"
    elif [ -e "$target" ]; then
      backup "$target" "$rel"
    fi
  done
}

main() {
  install_packages
  install_oh_my_posh

  info "Updating submodules"
  git -C "$DOTFILES" submodule update --init --recursive

  local packages=() dir
  for dir in "$DOTFILES"/*/; do
    packages+=("$(basename -- "$dir")")
  done

  for dir in "${packages[@]}"; do
    clear_conflicts "$DOTFILES/$dir" ""
  done

  info "Linking packages: ${packages[*]}"
  stow --dir="$DOTFILES" --target="$HOME" --restow "${packages[@]}"

  if [ -d "$BACKUP_DIR" ]; then
    info "Replaced files were saved to $BACKUP_DIR"
  fi
  info "Done"
}

main "$@"
