[[ -o interactive ]] || return 0
if [[ ! -o login && -f "$HOME/.zprofile" ]]; then
  source "$HOME/.zprofile"
fi

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

autoload -Uz compinit
compinit

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - --no-rehash zsh)"
fi
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd='z'
fi
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --git'
  alias ll='eza --icons --git -lah'
fi
if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
fi
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if [[ -f "$HOME/.secrets" ]]; then
  source "$HOME/.secrets"
fi
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
