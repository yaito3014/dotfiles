# Non-interactive shells (scp, ssh host cmd) must not load the prompt.
[[ $- != *i* ]] && return

# oh-my-posh
export PATH=$PATH:$HOME/.local/bin
eval "$(oh-my-posh init bash --config "$HOME/.oh-my-posh/config.toml")"

# shellcheck source=/dev/null
[ -f ~/.bashrc.local ] && source ~/.bashrc.local
