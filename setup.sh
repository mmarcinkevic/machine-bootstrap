#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }

# ── 1. Xcode Command Line Tools ──────────────────────────────────────────────
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools..."
  xcode-select --install
  read -rp "Press Enter after Xcode CLT installation finishes..."
else
  ok "Xcode Command Line Tools already installed"
fi

# ── 2. Homebrew ───────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(brew shellenv)"
else
  ok "Homebrew already installed"
fi

# ── 3. Brew Bundle ────────────────────────────────────────────────────────────
info "Installing formulae, casks, and extensions from Brewfile..."
brew bundle --file="$SCRIPT_DIR/Brewfile" --no-lock

# ── 4. Oh My Zsh + Powerlevel10k ─────────────────────────────────────────────
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  info "Installing Oh My Zsh..."
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  ok "Oh My Zsh already installed"
fi

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  info "Installing Powerlevel10k theme..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  ok "Powerlevel10k already installed"
fi

# ── 5. NVM + Node ────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  info "Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

info "Installing latest LTS Node via NVM..."
nvm install --lts
nvm use --lts

# ── 6. npm global packages ───────────────────────────────────────────────────
info "Installing npm global packages..."
xargs npm install -g < "$SCRIPT_DIR/node/global-packages.txt"

# ── 7. Python global packages ────────────────────────────────────────────────
info "Installing pip global packages..."
pip3 install -r "$SCRIPT_DIR/python/global-packages.txt"

# ── 8. Dotfiles ──────────────────────────────────────────────────────────────
link_dotfile() {
  local src="$1" dest="$2"
  if [ -f "$dest" ] && [ ! -L "$dest" ]; then
    warn "Backing up existing $dest to ${dest}.bak"
    mv "$dest" "${dest}.bak"
  fi
  ln -sf "$src" "$dest"
  ok "Linked $src -> $dest"
}

link_dotfile "$SCRIPT_DIR/dotfiles/.zshrc"     "$HOME/.zshrc"
link_dotfile "$SCRIPT_DIR/dotfiles/.zprofile"  "$HOME/.zprofile"
link_dotfile "$SCRIPT_DIR/dotfiles/.gitconfig" "$HOME/.gitconfig"

# ── 9. iTerm2 preferences ────────────────────────────────────────────────────
info "Importing iTerm2 preferences..."
ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
if [ -f "$ITERM_PLIST" ]; then
  warn "Backing up existing iTerm2 preferences to ${ITERM_PLIST}.bak"
  cp "$ITERM_PLIST" "${ITERM_PLIST}.bak"
fi
cp "$SCRIPT_DIR/iterm2/com.googlecode.iterm2.plist" "$ITERM_PLIST"
defaults read com.googlecode.iterm2 &>/dev/null
ok "iTerm2 preferences imported"

# ── 10. Cursor settings ──────────────────────────────────────────────────────
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
CURSOR_HOME="$HOME/.cursor"

mkdir -p "$CURSOR_USER_DIR"
mkdir -p "$CURSOR_HOME"

info "Copying Cursor settings..."
cp "$SCRIPT_DIR/cursor/settings.json"    "$CURSOR_USER_DIR/settings.json"
cp "$SCRIPT_DIR/cursor/keybindings.json" "$CURSOR_USER_DIR/keybindings.json"
ok "Cursor settings.json and keybindings.json copied"

info "Copying Cursor MCP config (remember to fill in API tokens)..."
cp "$SCRIPT_DIR/cursor/mcp.json" "$CURSOR_HOME/mcp.json"
warn "Edit ~/.cursor/mcp.json and replace __PLACEHOLDER__ tokens with real values"

# ── 11. Cursor extensions ────────────────────────────────────────────────────
if command -v cursor &>/dev/null; then
  info "Installing Cursor extensions..."
  while IFS= read -r ext; do
    [ -z "$ext" ] && continue
    cursor --install-extension "$ext" || warn "Failed to install extension: $ext"
  done < "$SCRIPT_DIR/cursor/extensions.txt"
  ok "Cursor extensions installed"
else
  warn "Cursor CLI not found -- install Cursor and run: cat cursor/extensions.txt | xargs -L1 cursor --install-extension"
fi

# ── 12. macOS defaults (optional) ────────────────────────────────────────────
if [ -f "$SCRIPT_DIR/macos/defaults.sh" ]; then
  info "Applying macOS defaults..."
  bash "$SCRIPT_DIR/macos/defaults.sh"
fi

# ── 13. Colima (Docker runtime) ──────────────────────────────────────────────
if command -v colima &>/dev/null; then
  info "Starting Colima (Docker runtime)..."
  colima start --cpu 4 --memory 8 --disk 60 2>/dev/null || ok "Colima already running"
else
  warn "Colima not found -- Docker runtime not started"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
ok "Bootstrap complete!"
echo ""
warn "Manual steps remaining:"
echo "  1. Generate a new SSH key:  ssh-keygen -t ed25519 -C \"your-email@example.com\""
echo "  2. Add SSH key to GitHub:   gh ssh-key add ~/.ssh/id_ed25519.pub"
echo "  3. Add signing key to .gitconfig"
echo "  4. Fill secrets in ~/.secrets (API keys, tokens)"
echo "  5. Fill tokens in ~/.cursor/mcp.json"
echo "  6. Restart iTerm2 to load imported preferences"
echo "  7. Run 'p10k configure' if Powerlevel10k prompt needs adjustment"
