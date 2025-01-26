# oh-my-zh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# oh-my-posh
export PATH=$PATH:$HOME/.local/bin
eval "$(oh-my-posh init zsh --config $HOME/.oh-my-posh/config.toml)"

# cargo
source $HOME/.cargo/env

# set env for WSL
export PATH=$PATH:/mnt/c/Users/kakeyamay/AppData/Local/Programs/Microsoft\ VS\ Code/bin
