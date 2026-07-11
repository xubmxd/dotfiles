# Path to Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="bureau"

# Plugins
plugins=(
    git
)

# Load Oh My Zsh
source "$ZSH/oh-my-zsh.sh"

# -------------------------
# Custom aliases
# -------------------------

alias ctlvpn='sudo openvpn ~/Desktop/ctfs/ctl.ovpn'
alias htbvpn='sudo openvpn ~/Desktop/ctfs/htb.ovpn'
alias thmvpn='sudo openvpn ~/Desktop/ctfs/thm.ovpn'

alias emoji='rofi -modi emoji -show emoji'

# -------------------------
# NVM
# -------------------------

export NVM_DIR="$HOME/.nvm"

[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

# Syntax highlighting
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


# -------------------------
# Startup
# -------------------------

fastfetch
