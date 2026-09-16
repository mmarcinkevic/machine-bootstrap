#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/setup.sh"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-test.XXXXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

printf 'new configuration\n' > "$TEMP_DIR/source"
destination="$TEMP_DIR/home with spaces/config"
install_config "$TEMP_DIR/source" "$destination"
cmp "$TEMP_DIR/source" "$destination"
install_config "$TEMP_DIR/source" "$destination"
[[ -z "$(find "$TEMP_DIR" -name '*.backup.*' -print)" ]]

printf 'local changes\n' > "$destination"
install_config "$TEMP_DIR/source" "$destination"
[[ "$(cat "$destination")" == 'local changes' ]]
[[ "$PRESERVED" -eq 1 ]]

DRY_RUN=true
REPLACE_CONFIG=true
install_config "$TEMP_DIR/source" "$destination"
install_config "$TEMP_DIR/source" "$TEMP_DIR/absent/config"
[[ "$(cat "$destination")" == 'local changes' ]]
[[ ! -e "$TEMP_DIR/absent" ]]
[[ -z "$(find "$TEMP_DIR" -name '*.backup.*' -print)" ]]

DRY_RUN=false
install_config "$TEMP_DIR/source" "$destination"
cmp "$TEMP_DIR/source" "$destination"
[[ "$(cat "$destination".backup.*/original)" == 'local changes' ]]
printf 'second local change\n' > "$destination"
install_config "$TEMP_DIR/source" "$destination"
[[ "$(find "$TEMP_DIR" -name original | wc -l | tr -d ' ')" -eq 2 ]]

printf 'external content\n' > "$TEMP_DIR/external"
ln -s "$TEMP_DIR/external" "$TEMP_DIR/link"
install_config "$TEMP_DIR/source" "$TEMP_DIR/link"
[[ ! -L "$TEMP_DIR/link" ]]
[[ "$(cat "$TEMP_DIR/external")" == 'external content' ]]
link_backups=("$TEMP_DIR/link".backup.*/original)
[[ "${#link_backups[@]}" -eq 1 && -L "${link_backups[0]}" ]]

ln -s "$TEMP_DIR/missing" "$TEMP_DIR/broken"
REPLACE_CONFIG=false
install_config "$TEMP_DIR/source" "$TEMP_DIR/broken"
[[ -L "$TEMP_DIR/broken" ]]
REPLACE_CONFIG=true
install_config "$TEMP_DIR/source" "$TEMP_DIR/broken"
cmp "$TEMP_DIR/source" "$TEMP_DIR/broken"

mkdir "$TEMP_DIR/directory"
if (install_config "$TEMP_DIR/source" "$TEMP_DIR/directory"); then
  die 'Directory destination should have failed.'
fi
if (install_config "$TEMP_DIR/missing" "$TEMP_DIR/new"); then
  die 'Missing source should have failed.'
fi
bash "$ROOT/setup.sh" --help >/dev/null
if bash "$ROOT/setup.sh" --unknown >/dev/null 2>&1; then
  die 'Unknown option should have failed.'
fi
printf 'Configuration safety tests passed.\n'

mkdir -p "$TEMP_DIR/bin" "$TEMP_DIR/state"
cat > "$TEMP_DIR/bin/mock" <<'MOCK'
#!/bin/bash
set -eu
command_name="${0##*/}"
printf '%s %s\n' "$command_name" "$*" >> "$MOCK_LOG"
if [[ "${MOCK_FAIL:-}" == "$command_name:${1:-}" ]]; then
  printf 'Simulated failure: %s\n' "$MOCK_FAIL" >&2
  exit 17
fi
case "$command_name:${1:-}" in
  uname:-s) printf '%s\n' "${MOCK_OS:-Darwin}" ;;
  xcode-select:-p) printf '/mock/CommandLineTools\n' ;;
  brew:shellenv) printf 'export HOMEBREW_PREFIX=%q\n' "$MOCK_STATE/brew" ;;
  brew:bundle) [[ "$*" == *--no-upgrade* ]] ;;
  npm:list) [[ -f "$MOCK_STATE/npm-installed" ]] ;;
  npm:install) touch "$MOCK_STATE/npm-installed" ;;
  code:--list-extensions)
    if [[ -f "$MOCK_STATE/extensions" ]]; then cat "$MOCK_STATE/extensions"; fi
    ;;
  code:--install-extension) printf '%s\n' "$2" >> "$MOCK_STATE/extensions" ;;
  defaults:write) ;;
  *) printf 'Unexpected mock command: %s %s\n' "$command_name" "$*" >&2; exit 99 ;;
esac
MOCK
chmod +x "$TEMP_DIR/bin/mock"
for command_name in brew code npm xcode-select defaults uname; do
  ln -s mock "$TEMP_DIR/bin/$command_name"
done

MOCK_HOME="$TEMP_DIR/fresh home"
MOCK_STATE="$TEMP_DIR/state"
MOCK_LOG="$TEMP_DIR/commands.log"
mock_setup() {
  env -i HOME="$MOCK_HOME" PATH="$TEMP_DIR/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" MOCK_FAIL="${MOCK_FAIL:-}" \
    MOCK_OS="${MOCK_OS:-Darwin}" XDG_CONFIG_HOME="${MOCK_XDG:-}" \
    /bin/bash "$ROOT/setup.sh" "$@"
}

mock_setup --dry-run --with-optional --with-mcp --macos-defaults > "$TEMP_DIR/preview.log"
[[ ! -e "$MOCK_HOME" ]]
if grep -Eq '^(brew|code|npm|defaults) ' "$MOCK_LOG"; then
  die 'Dry run invoked a mutating tool.'
fi

mock_setup > "$TEMP_DIR/first-run.log"
cmp "$ROOT/dotfiles/.zshrc" "$MOCK_HOME/.zshrc"
cmp "$ROOT/vscode/settings.json" "$MOCK_HOME/Library/Application Support/Code/User/settings.json"
[[ ! -e "$MOCK_HOME/Library/Application Support/Code/User/mcp.json" ]]
[[ "$(grep -c '^code --install-extension ' "$MOCK_LOG")" -eq "$(wc -l < "$ROOT/vscode/extensions.txt" | tr -d ' ')" ]]
if grep -Eq 'Brewfile.optional|^defaults ' "$MOCK_LOG"; then
  die 'Default setup ran an opt-in operation.'
fi
cp -R "$MOCK_HOME" "$TEMP_DIR/snapshot"
mock_setup > "$TEMP_DIR/second-run.log"
diff -r "$MOCK_HOME" "$TEMP_DIR/snapshot"
[[ "$(grep -c '^npm install ' "$MOCK_LOG")" -eq 1 ]]
[[ "$(grep -c '^code --install-extension ' "$MOCK_LOG")" -eq "$(wc -l < "$ROOT/vscode/extensions.txt" | tr -d ' ')" ]]

printf 'local shell\n' > "$MOCK_HOME/.zshrc"
printf 'local git identity\n' > "$MOCK_HOME/.gitconfig.local"
mock_setup --config-only > "$TEMP_DIR/preserve.log" 2>&1
[[ "$(cat "$MOCK_HOME/.zshrc")" == 'local shell' ]]
mock_setup --config-only --replace-config --with-mcp > "$TEMP_DIR/replace.log"
cmp "$ROOT/dotfiles/.zshrc" "$MOCK_HOME/.zshrc"
cmp "$ROOT/vscode/mcp.json" "$MOCK_HOME/Library/Application Support/Code/User/mcp.json"
[[ "$(cat "$MOCK_HOME/.gitconfig.local")" == 'local git identity' ]]

mock_setup --with-optional --macos-defaults > "$TEMP_DIR/optional.log"
grep -q 'Brewfile.optional' "$MOCK_LOG"
[[ "$(grep -c '^defaults write ' "$MOCK_LOG")" -eq 7 ]]

for failure in brew:shellenv brew:bundle npm:install code:--list-extensions code:--install-extension xcode-select:-p; do
  MOCK_HOME="$TEMP_DIR/failure-home-$failure"
  MOCK_STATE="$TEMP_DIR/failure-state-$failure"
  mkdir "$MOCK_STATE"
  if MOCK_FAIL="$failure" mock_setup > "$TEMP_DIR/failure.log" 2>&1; then
    die "Setup swallowed failure: $failure"
  fi
  [[ ! -f "$MOCK_HOME/.zshrc" ]]
  if grep -q 'Setup finished' "$TEMP_DIR/failure.log"; then
    die 'Failed setup reported success.'
  fi
done
if MOCK_OS=Linux mock_setup --config-only > "$TEMP_DIR/platform.log" 2>&1; then
  die 'Unsupported OS should fail.'
fi
if MOCK_XDG=relative mock_setup --config-only > "$TEMP_DIR/xdg.log" 2>&1; then
  die 'Relative XDG_CONFIG_HOME should fail.'
fi

MOCK_HOME="$TEMP_DIR/config-only home"
MOCK_XDG="$TEMP_DIR/xdg config"
mock_setup --config-only --with-mcp > "$TEMP_DIR/config-only.log"
cmp "$ROOT/dotfiles/starship.toml" "$MOCK_XDG/starship.toml"
[[ ! -e "$MOCK_HOME/.config/starship.toml" ]]
env -i HOME="$MOCK_HOME" ZDOTDIR="$MOCK_HOME" \
  PATH="$TEMP_DIR/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  MOCK_LOG="$MOCK_LOG" MOCK_STATE="$MOCK_STATE" \
  /bin/zsh -d -i -c '[[ "$path[1]" == "$HOME/.local/share/npm/bin" ]]' \
  > "$TEMP_DIR/shell.log" 2>&1
[[ ! -s "$TEMP_DIR/shell.log" ]]

printf 'Mocked installer, repeatability, opt-in, shell startup, and failure-path tests passed.\n'
