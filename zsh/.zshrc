# history
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000
setopt extended_history hist_expire_dups_first hist_ignore_dups \
  hist_ignore_space hist_verify share_history

# completion
autoload -Uz compinit && compinit
zmodload zsh/complist
setopt auto_menu complete_in_word always_to_end
unsetopt menu_complete flow_control
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ''

# key bindings
WORDCHARS=''
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search
bindkey '^[[H' beginning-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OF' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[Z' reverse-menu-complete

# oh-my-posh
eval "$(oh-my-posh init zsh --config $HOME/.oh-my-posh/config.toml)"

[ -f ~/.zshrc.local ] && source ~/.zshrc.local
