export ZSH="$HOME/.oh-my-zsh"

# Enable plugins (add more if needed)
plugins=(git)

# Source Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Load Powerlevel10k configuration if it exists
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Homebrew
eval "$(brew shellenv)"

# Paths
export PATH="/usr/local/bin:$PATH"
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - zsh)"

# GHCup (Haskell toolchain)
[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"

# kubectl completions
if command -v kubectl &>/dev/null; then
  source <(kubectl completion zsh)
fi

# Final PATH adjustments
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:/usr/local/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Secrets -- set these in ~/.secrets or via 1Password CLI
# export ANTHROPIC_API_KEY="..."
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
