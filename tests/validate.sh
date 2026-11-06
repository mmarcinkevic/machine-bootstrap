#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for script in setup.sh macos/defaults.sh tests/setup.sh tests/validate.sh; do
  bash -n "$script"
done
for config in dotfiles/.zprofile dotfiles/.zshrc; do
  zsh -n "$config"
done

python3 - <<'PY'
import json
import pathlib
import re
import tomllib

root = pathlib.Path.cwd()
settings = json.loads((root / 'vscode/settings.json').read_text())
bindings = json.loads((root / 'vscode/keybindings.json').read_text())
mcp = json.loads((root / 'vscode/mcp.json').read_text())
tomllib.loads((root / 'dotfiles/starship.toml').read_text())
assert isinstance(settings, dict) and isinstance(bindings, list)
assert not any(key in settings for key in (
    'cloudcode.project', '@azure.argTenant', 'python.pythonPath',
    'python.defaultInterpreterPath', 'chat.tools.urls.autoApprove',
    'chatgpt.cliExecutable', 'files.dialog.defaultPath',
    'security.workspace.trust.untrustedFiles',
))
inputs = {entry['id']: entry for entry in mcp['inputs']}
assert len(inputs) == len(mcp['inputs'])
for server in mcp['servers'].values():
    assert server['type'] == 'stdio'
    for variable, value in server['env'].items():
        match = re.fullmatch(r'\$\{input:([^}]+)\}', value)
        assert match and match[1] in inputs, variable
        if 'TOKEN' in variable or 'USERNAME' in variable:
            assert inputs[match[1]].get('password') is True, variable

for filename, pattern in (
    ('vscode/extensions.txt', r'[a-z0-9-]+\.[a-z0-9-]+'),
    ('node/global-packages.txt', r'(?:@[a-z0-9-]+/)?[a-z0-9-]+(?:@[^\s]+)?'),
):
    entries = [line for line in (root / filename).read_text().splitlines()
               if line and not line.startswith('#')]
    assert len(entries) == len(set(entries)), filename
    assert all(re.fullmatch(pattern, entry) for entry in entries), filename

manifests = '\n'.join((root / filename).read_text()
                      for filename in ('Brewfile', 'Brewfile.optional'))
assert not re.search(r'\bvscode\s+"|restart_service|iterm2|cursor|powerlevel10k', manifests)
entries = re.findall(r'^\s*(brew|cask) "([^"]+)"', manifests, re.M)
assert len(entries) == len(set(entries))
assert ('cask', 'ghostty') in entries and ('cask', 'visual-studio-code') in entries

patterns = [
    re.compile(r'-----BEGIN (?:OPENSSH |RSA |EC )?PRIVATE KEY-----'),
    re.compile(r'gh[pousr]_[A-Za-z0-9]{30,}'),
    re.compile(r'github_pat_[A-Za-z0-9_]{30,}'),
    re.compile(r'AKIA[A-Z0-9]{16}'),
    re.compile(r'sk-(?:ant-)?[A-Za-z0-9_-]{30,}'),
]
for directory in ('dotfiles', 'vscode', 'ghostty'):
    for path in (root / directory).iterdir():
        text = path.read_text()
        assert '/Users/' not in text, f'Machine path in {path.relative_to(root)}'
        assert not any(pattern.search(text) for pattern in patterns), \
            f'Possible credential in {path.relative_to(root)}'
print('Structured configuration, manifest, and sensitive-pattern checks passed.')
PY

bash tests/setup.sh

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck setup.sh macos/defaults.sh tests/setup.sh tests/validate.sh
else
  printf '[SKIP] ShellCheck is not installed.\n'
fi
if command -v brew >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --all --file=Brewfile >/dev/null
  HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --all --file=Brewfile.optional >/dev/null
  # Avoid persisting developer mode when invoking Homebrew's Ruby runner.
  HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_DEVELOPER=1 brew ruby - "$ROOT/Brewfile.optional" <<'RUBY'
require "bundle/dsl"
require "macos_version"

[["15", true, false], ["26", true, true], ["27", true, true], ["26", false, false]].each do |version, arm, expected|
  MacOS.define_singleton_method(:version) { MacOSVersion.new(version) }
  Hardware::CPU.define_singleton_method(:arm?) { arm }
  entries = Homebrew::Bundle::Dsl.new(Pathname.new(ARGV.fetch(0))).entries
  unless entries.any? { |entry| entry.name == "container" } == expected
    abort "Incorrect Container selection for macOS #{version}, arm=#{arm}"
  end
end
puts "Optional Container architecture and macOS compatibility checks passed."
RUBY
else
  printf '[SKIP] Homebrew manifest parser is not installed.\n'
fi
if [[ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]]; then
  /Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config --config-file="$ROOT/ghostty/config.ghostty"
else
  printf '[SKIP] Ghostty validator is not installed.\n'
fi
if command -v starship >/dev/null 2>&1; then
  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-prompt.XXXXXXXX")"
  trap 'rm -rf "$TEMP_DIR"' EXIT
  env -i HOME="$TEMP_DIR" PATH="$PATH" STARSHIP_CONFIG="$ROOT/dotfiles/starship.toml" \
    "$(command -v starship)" prompt --path "$TEMP_DIR" > "$TEMP_DIR/prompt" 2> "$TEMP_DIR/errors"
  [[ -s "$TEMP_DIR/prompt" && ! -s "$TEMP_DIR/errors" ]]
else
  printf '[SKIP] Starship parser is not installed.\n'
fi
git diff --check
printf 'Validation passed (see any skipped optional checks above).\n'
