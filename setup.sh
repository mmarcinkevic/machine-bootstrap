#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
CONFIG_ONLY=false
REPLACE_CONFIG=false
WITH_OPTIONAL=false
WITH_MCP=false
MACOS_DEFAULTS=false
PRESERVED=0

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  printf '%s\n' \
    'Usage: bash setup.sh [options]' \
    '  --dry-run          Preview actions without writing or installing anything' \
    '  --config-only      Install configuration files only' \
    '  --replace-config   Back up and replace conflicting configuration files' \
    '  --with-optional    Also install Brewfile.optional (no services are started)' \
    '  --with-mcp         Install the VS Code Atlassian MCP template' \
    '  --macos-defaults   Apply the reviewed macOS preferences' \
    '  --help             Show this help'
}

run() {
  if "$DRY_RUN"; then
    printf '[PLAN]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

install_config() {
  local source="$1" destination="$2" backup
  [[ -f "$source" ]] || die "Missing configuration source: $source"
  [[ ! -d "$destination" ]] || die "Refusing to replace a directory: $destination"
  if [[ -f "$destination" ]] && cmp -s "$source" "$destination"; then
    info "Unchanged: $destination"
    return
  fi
  if [[ -e "$destination" || -L "$destination" ]]; then
    if ! "$REPLACE_CONFIG"; then
      warn "Preserved existing configuration: $destination (use --replace-config after review)"
      PRESERVED=$((PRESERVED + 1))
      return
    fi
    if "$DRY_RUN"; then
      info "Would back up and replace: $destination"
      return
    fi
    backup="$(mktemp -d "${destination}.backup.XXXXXXXX")"
    mv "$destination" "$backup/original"
    info "Backup: $backup/original"
  fi
  run mkdir -p "$(dirname "$destination")"
  run cp "$source" "$destination"
}

find_brew() {
  local candidate
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return
  fi
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew "$HOME/homebrew/bin/brew"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

find_code() {
  local candidate
  if command -v code >/dev/null 2>&1; then
    command -v code
    return
  fi
  for candidate in \
    '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code' \
    "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

install_packages() {
  local brew_bin brew_environment code_bin package installed_extensions extension
  if ! "$DRY_RUN"; then
    xcode-select -p >/dev/null 2>&1 || die 'Install Xcode Command Line Tools with xcode-select --install, wait for completion, then rerun.'
  fi
  if brew_bin="$(find_brew)"; then
    if ! "$DRY_RUN"; then
      brew_environment="$("$brew_bin" shellenv)"
      eval "$brew_environment"
    fi
  elif "$DRY_RUN"; then
    brew_bin=brew
    info 'Homebrew is a prerequisite; see README.md for installation.'
  else
    die 'Homebrew is missing. Install it from https://brew.sh, then rerun. Do not run setup with sudo.'
  fi
  run "$brew_bin" bundle install --file="$SCRIPT_DIR/Brewfile" --no-upgrade
  if "$WITH_OPTIONAL"; then
    run "$brew_bin" bundle install --file="$SCRIPT_DIR/Brewfile.optional" --no-upgrade
  fi
  if ! "$DRY_RUN"; then
    [[ -x "$HOMEBREW_PREFIX/opt/node@24/bin/node" ]] || die 'Homebrew Node 24 is missing; install node@24 and rerun.'
    export PATH="$HOMEBREW_PREFIX/opt/node@24/bin:$PATH"
  fi
  while IFS= read -r package || [[ -n "$package" ]]; do
    [[ -n "$package" && "$package" != \#* ]] || continue
    if ! "$DRY_RUN" && npm list --global --prefix "$HOME/.local/share/npm" "$package" --depth=0 >/dev/null 2>&1; then
      info "npm package already installed: $package"
    else
      run npm install --global --prefix "$HOME/.local/share/npm" "$package"
    fi
  done < "$SCRIPT_DIR/node/global-packages.txt"
  if "$DRY_RUN"; then
    info 'Would install missing VS Code extensions from vscode/extensions.txt using the app-bundled CLI.'
    return
  fi
  code_bin="$(find_code)" || die 'VS Code CLI not found after installation.'
  installed_extensions="$("$code_bin" --list-extensions)"
  while IFS= read -r extension || [[ -n "$extension" ]]; do
    [[ -n "$extension" && "$extension" != \#* ]] || continue
    if printf '%s\n' "$installed_extensions" | grep -Fxiq -- "$extension"; then
      info "Extension already installed: $extension"
    else
      "$code_bin" --install-extension "$extension"
    fi
  done < "$SCRIPT_DIR/vscode/extensions.txt"
}

install_configs() {
  local code_user="$HOME/Library/Application Support/Code/User"
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  install_config "$SCRIPT_DIR/dotfiles/.zprofile" "$HOME/.zprofile"
  install_config "$SCRIPT_DIR/dotfiles/.zshrc" "$HOME/.zshrc"
  install_config "$SCRIPT_DIR/dotfiles/.gitconfig" "$HOME/.gitconfig"
  install_config "$SCRIPT_DIR/dotfiles/starship.toml" "$config_home/starship.toml"
  install_config "$SCRIPT_DIR/ghostty/config.ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
  install_config "$SCRIPT_DIR/vscode/settings.json" "$code_user/settings.json"
  install_config "$SCRIPT_DIR/vscode/keybindings.json" "$code_user/keybindings.json"
  if "$WITH_MCP"; then
    install_config "$SCRIPT_DIR/vscode/mcp.json" "$code_user/mcp.json"
  fi
}

main() {
  local option source
  for option in "$@"; do
    case "$option" in
      --dry-run) DRY_RUN=true ;;
      --config-only) CONFIG_ONLY=true ;;
      --replace-config) REPLACE_CONFIG=true ;;
      --with-optional) WITH_OPTIONAL=true ;;
      --with-mcp) WITH_MCP=true ;;
      --macos-defaults) MACOS_DEFAULTS=true ;;
      --help|-h) usage; return ;;
      *) usage >&2; die "Unknown option: $option" ;;
    esac
  done
  [[ "$(uname -s)" == Darwin ]] || die 'This bootstrap supports macOS only.'
  [[ "$EUID" -ne 0 ]] || die 'Run as your normal user, not with sudo.'
  [[ -n "${HOME:-}" && "$HOME" == /* && "$HOME" != / ]] || die 'HOME must be an absolute user home directory.'
  [[ -z "${XDG_CONFIG_HOME:-}" || "$XDG_CONFIG_HOME" == /* ]] || die 'XDG_CONFIG_HOME must be absolute.'
  for source in Brewfile Brewfile.optional node/global-packages.txt dotfiles/.zprofile dotfiles/.zshrc \
    dotfiles/.gitconfig dotfiles/starship.toml ghostty/config.ghostty vscode/settings.json \
    vscode/keybindings.json vscode/extensions.txt vscode/mcp.json macos/defaults.sh; do
    [[ -f "$SCRIPT_DIR/$source" ]] || die "Missing repository file: $source"
  done
  if ! "$CONFIG_ONLY"; then
    install_packages
  fi
  install_configs
  if "$MACOS_DEFAULTS"; then
    run bash "$SCRIPT_DIR/macos/defaults.sh"
  fi
  if "$DRY_RUN"; then
    info 'Preview complete. Nothing was installed or changed.'
  else
    info "Setup finished; $PRESERVED conflicting configuration file(s) preserved."
    info 'See README.md for login, Git identity/signing, Docker startup, and optional MCP steps.'
    info 'Setup did not request service or Docker startup. Open a new terminal to load shell changes.'
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  trap 'printf "[ERROR] Setup stopped at line %s. Resolve the error and rerun.\n" "$LINENO" >&2' ERR
  main "$@"
fi
