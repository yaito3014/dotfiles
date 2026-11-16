#!/bin/sh
# Set up the dotfiles on a Debian/Ubuntu machine, or bring an existing setup
# up to date. Safe to re-run.
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/yaito3014/dotfiles/main/install.sh)"
#
# Run it via `sh -c` rather than `curl | sh` so prompts (sudo, gh auth login)
# can read the terminal.
#
#   DOTFILES_DIR      clone to link from (default: ~/.local/share/dotfiles)
#   DOTFILES_RUNNER   set to 0 to skip the self-hosted runner
set -eu

repo_url=https://github.com/yaito3014/dotfiles.git
dir=${DOTFILES_DIR:-$HOME/.local/share/dotfiles}
runner_repo=yaito3014/ops
runner_user=gh-runner
runner_dir=/home/$runner_user/actions-runner
user=$(id -un)
bin=$HOME/.local/bin

log() {
    printf '==> %s\n' "$*"
}

as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

ensure_packages() {
    missing=
    for pkg in "$@"; do
        dpkg-query -W -f '${Status}\n' "$pkg" 2>/dev/null | grep -q ' installed$' ||
            missing="$missing $pkg"
    done
    [ -n "$missing" ] || return 0
    log "installing$missing"
    as_root apt-get update -q
    # shellcheck disable=SC2086 # one word per package
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -q $missing
}

# Stage 1, e.g. when piped from curl: make sure the clone exists and is
# current, then continue with the clone's own copy of this script.
bootstrap() {
    ensure_packages git ca-certificates
    if [ -e "$dir" ]; then
        log "updating $dir"
        git -C "$dir" pull --quiet --ff-only
    else
        log "cloning into $dir"
        mkdir -p "$(dirname "$dir")"
        git clone --quiet "$repo_url" "$dir"
    fi
    exec sh "$dir/install.sh"
}

install_tools() {
    mkdir -p "$bin"
    if ! command -v mise >/dev/null && [ ! -x "$bin/mise" ]; then
        log "installing mise"
        curl -fsSL https://mise.run | sh
    fi
    if ! command -v oh-my-posh >/dev/null && [ ! -x "$bin/oh-my-posh" ]; then
        log "installing oh-my-posh"
        curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$bin"
    fi
}

set_login_shell() {
    zsh=$(command -v zsh)
    [ "$(getent passwd "$user" | cut -d: -f7)" != "$zsh" ] || return 0
    log "changing login shell to $zsh"
    as_root chsh -s "$zsh" "$user"
}

gh() {
    mise=$(command -v mise || echo "$bin/mise")
    "$mise" exec gh@latest -- gh "$@"
}

ensure_gh_auth() {
    gh auth status >/dev/null 2>&1 && return 0
    if [ ! -t 0 ]; then
        echo "gh is not logged in and there is no terminal to log in from;" \
            "run 'gh auth login' first or re-run with sh -c" >&2
        return 1
    fi
    gh auth login --hostname github.com --git-protocol https
}

as_runner() {
    as_root runuser -u "$runner_user" -- "$@"
}

# The runner can only write the trigger file that dotfiles-sync.path watches;
# the sync itself runs as $user.
setup_trigger() {
    id "$runner_user" >/dev/null 2>&1 ||
        as_root useradd --system --create-home --home-dir "/home/$runner_user" \
            --shell /usr/sbin/nologin "$runner_user"
    printf '%s\n' \
        "d /run/dotfiles-sync 0770 $user $runner_user -" \
        "f /run/dotfiles-sync/trigger 0660 $user $runner_user -" |
        as_root tee /etc/tmpfiles.d/dotfiles-sync.conf >/dev/null
    as_root systemd-tmpfiles --create /etc/tmpfiles.d/dotfiles-sync.conf
}

# The ops workflow targets each machine through a label equal to its runner
# name, so every machine gets its own sync job.
setup_runner() {
    host=$(uname -n)
    ensure_gh_auth
    if as_root test -f "$runner_dir/.runner"; then
        info=$(gh api "repos/$runner_repo/actions/runners" --paginate --jq \
            ".runners[] | select(.name == \"$host\")
             | \"\(.id) \(any(.labels[]; .name == \"$host\"))\"")
        id=${info% *}
        if [ -n "$info" ] && [ "${info#* }" != true ]; then
            log "adding label $host to runner $host"
            gh api -X POST "repos/$runner_repo/actions/runners/$id/labels" \
                -f "labels[]=$host" >/dev/null
        fi
        return 0
    fi

    case $(uname -m) in
    x86_64) arch=x64 ;;
    aarch64) arch=arm64 ;;
    *)
        echo "no actions runner build for $(uname -m)" >&2
        return 1
        ;;
    esac
    version=$(gh api repos/actions/runner/releases/latest --jq '.tag_name | ltrimstr("v")')
    log "installing actions runner $version as $host"
    as_runner mkdir -p "$runner_dir"
    curl -fsSL "https://github.com/actions/runner/releases/download/v$version/actions-runner-linux-$arch-$version.tar.gz" |
        as_runner tar -xz -C "$runner_dir"
    as_root "$runner_dir/bin/installdependencies.sh"
    token=$(gh api -X POST "repos/$runner_repo/actions/runners/registration-token" --jq .token)
    # shellcheck disable=SC2016 # expanded by the inner sh
    as_runner sh -c 'cd "$1" && ./config.sh --unattended --replace \
        --url "https://github.com/$2" --token "$3" --name "$4" --labels "$4"' \
        sh "$runner_dir" "$runner_repo" "$token" "$host"
    # shellcheck disable=SC2016 # expanded by the inner sh
    as_root sh -c 'cd "$1" && ./svc.sh install "$2" && ./svc.sh start' \
        sh "$runner_dir" "$runner_user"
}

enable_units() {
    as_root loginctl enable-linger "$user"
    if ! systemctl --user show-environment >/dev/null 2>&1; then
        echo "warning: no systemd user manager in this session;" \
            "enable dotfiles-sync.timer (and .path) by hand" >&2
        return 0
    fi
    systemctl --user daemon-reload
    systemctl --user enable --now dotfiles-sync.timer
    if [ "${DOTFILES_RUNNER:-1}" != 0 ]; then
        systemctl --user enable --now dotfiles-sync.path
    fi
}

if [ ! -f /etc/debian_version ]; then
    echo "only Debian and Ubuntu are supported" >&2
    exit 1
fi

here=
[ ! -f "$0" ] || here=$(cd -P "$(dirname "$0")" && pwd)
if [ -z "$here" ] || [ "$here" != "$(cd -P "$dir" 2>/dev/null && pwd || true)" ]; then
    bootstrap
fi

ensure_packages git stow zsh curl unzip ca-certificates
install_tools
log "linking dotfiles from $dir"
"$dir/link.sh"
set_login_shell

if [ ! -d /run/systemd/system ]; then
    echo "warning: systemd is not running; skipping automatic sync" >&2
    exit 0
fi
if [ "${DOTFILES_RUNNER:-1}" != 0 ]; then
    setup_trigger
    setup_runner
fi
enable_units
log "done; open a new shell to pick up the changes"
