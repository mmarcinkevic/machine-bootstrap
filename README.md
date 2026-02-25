# machine-bootstrap

One-command setup for a new macOS development machine. Installs all tools, languages, editor config, shell setup, and preferences.

## Quick Start

```bash
git clone git@github.com:mmarcinkevic/machine-bootstrap.git
cd machine-bootstrap
./setup.sh
```

## What Gets Installed

| Category | What | How |
|---|---|---|
| **Homebrew** | All formulae and casks | `Brewfile` via `brew bundle` |
| **Shell** | Oh My Zsh + Powerlevel10k + zshrc | Symlinked from `dotfiles/` |
| **iTerm2** | App (via cask) + full preferences | Plist copied to `~/Library/Preferences/` |
| **Git** | Config with LFS, GPG signing via 1Password | Symlinked from `dotfiles/.gitconfig` |
| **Node.js** | NVM + latest LTS + global packages | `node/global-packages.txt` |
| **Python** | Python 3 (via brew) + pip packages | `python/global-packages.txt` |
| **Go, Rust, Ruby** | Via Homebrew + rbenv | `Brewfile` |
| **Cursor** | Settings, keybindings, MCP config, extensions | Copied to Cursor config dirs |
| **Docker** | Colima runtime (not Docker Desktop) | `Brewfile` + auto-start in setup |
| **Cloud/Infra** | azure-cli, kubectl, minikube, terragrunt | `Brewfile` |
| **macOS** | Key repeat, Finder, Dock preferences | `macos/defaults.sh` |

## Repo Structure

```
.
├── setup.sh                  # Master bootstrap script
├── Brewfile                  # Homebrew formulae, casks, extensions
├── dotfiles/
│   ├── .zshrc                # Shell config (Oh My Zsh + p10k + nvm)
│   ├── .zprofile             # Login shell profile
│   └── .gitconfig            # Git config (1Password SSH signing)
├── iterm2/
│   └── com.googlecode.iterm2.plist   # Full iTerm2 preferences
├── cursor/
│   ├── settings.json         # Editor settings
│   ├── keybindings.json      # Key bindings
│   ├── mcp.json              # MCP server config (tokens templated)
│   └── extensions.txt        # Extension IDs, one per line
├── node/
│   └── global-packages.txt   # npm -g packages
├── python/
│   └── global-packages.txt   # pip packages
└── macos/
    └── defaults.sh           # macOS system preferences
```

## After Setup -- Manual Steps

1. **SSH key** -- generate and add to GitHub:
   ```bash
   ssh-keygen -t ed25519 -C "marcinkevic.martin@gmail.com"
   gh ssh-key add ~/.ssh/id_ed25519.pub
   ```
2. **Git signing key** -- update `~/.gitconfig` with the new SSH public key under `[user] signingkey`
3. **Secrets** -- create `~/.secrets` with API keys (sourced by `.zshrc`):
   ```bash
   export ANTHROPIC_API_KEY="..."
   ```
4. **Cursor MCP tokens** -- edit `~/.cursor/mcp.json` and replace `__PLACEHOLDER__` values
5. **iTerm2** -- restart iTerm2 to pick up imported preferences
6. **Powerlevel10k** -- run `p10k configure` if the prompt needs tweaking

## Updating This Repo

When you install new tools or change settings, update the repo:

```bash
# Re-export Brewfile
brew bundle dump --file=Brewfile --force

# Re-export Cursor extensions
ls ~/.cursor/extensions/ | sed 's/-[0-9].*//' | sort -u > cursor/extensions.txt

# Re-export iTerm2 preferences
plutil -convert xml1 -o iterm2/com.googlecode.iterm2.plist ~/Library/Preferences/com.googlecode.iterm2.plist

# Commit
git add -A && git commit -m "update configs"
git push
```

## Security

- **No secrets in this repo.** API keys and tokens are either templated (`__PLACEHOLDER__`) or loaded from `~/.secrets` (gitignored).
- SSH keys are generated fresh on each machine.
- Git signing uses 1Password SSH agent.
