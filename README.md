# machine-bootstrap

Repeatable macOS development setup for Ghostty, Visual Studio Code, Zsh with
Starship, Homebrew runtimes, and Docker Desktop. Reviewed against the current
Apple Silicon Mac on 2026-09-16. This recreates a curated development environment,
not a disk image or an exact version-locked snapshot.

## Prerequisites

1. Use a macOS release supported by current Homebrew and the listed applications.
   The core setup supports Apple Silicon and Intel; Apple's optional `container`
   tool is Apple Silicon only. This revision was tested on Apple Silicon macOS 26.
2. Install Xcode Command Line Tools, and wait for the installer to finish:

   ```bash
   xcode-select --install
   xcode-select -p
   ```

3. Install Homebrew using the instructions at [brew.sh](https://brew.sh). Review
   its installer and enter any administrator password directly in your terminal.
   These two prerequisite installers are deliberately left interactive, outside
   this script. Do not run the bootstrap with `sudo`.
4. Have internet access to Homebrew, GitHub, the VS Code Marketplace, and npm.
   The optional MCP server also needs access to its container registry and your
   Atlassian sites. Corporate networks may require approved certificates or VPN.

Prefer Homebrew's supported prefix: `/opt/homebrew` on Apple Silicon or
`/usr/local` on Intel. An existing `brew` on `PATH` is respected; the scripts also
recognize those prefixes and `$HOME/homebrew` for the current Mac. The latter is
a compatibility fallback, not a recommended layout for a new machine. For any
other custom prefix, put `brew` on `PATH` first.

## Quick Start

```bash
git clone https://github.com/mmarcinkevic/machine-bootstrap.git
cd machine-bootstrap
bash setup.sh --dry-run
bash setup.sh
```

HTTPS avoids requiring a new SSH key before setup. If repository access requires
authentication, authenticate GitHub first or download its archive in your browser.
Use `bash setup.sh` so setup does not depend on an executable file bit. No tools,
services, or live settings are changed by `--dry-run`.

On an existing machine, quit VS Code and Ghostty before replacing their settings.
Choose whether this repository or VS Code Settings Sync owns your editor settings;
Sync can overwrite local changes after sign-in.

## Options

| Option | Effect |
| --- | --- |
| `--dry-run` | Preview any combination of options without writes or installer calls. |
| `--config-only` | Skip package and extension installation; useful for migration or offline configuration. |
| `--replace-config` | Back up and replace differing files. Without this, existing files win. |
| `--with-optional` | Install [Brewfile.optional](Brewfile.optional); do not request service startup. |
| `--with-mcp` | Install the opt-in VS Code Atlassian MCP template. |
| `--macos-defaults` | Apply the seven reviewed Finder/Dock preferences. |
| `--help` | Show command help. |

For example, preview a configuration migration before applying it:

```bash
bash setup.sh --config-only --replace-config --with-mcp --dry-run
bash setup.sh --config-only --replace-config --with-mcp
```

## What Is Managed

| Source | Purpose |
| --- | --- |
| [Brewfile](Brewfile) | Explicit development CLIs, maintained runtimes, Ghostty, VS Code, Docker Desktop, 1Password, Postman, Claude, Claude Code, Codex, devtunnel, ngrok, and Hack Nerd Font. |
| [Brewfile.optional](Brewfile.optional) | Colima, minikube, Prometheus, Grafana, slackdump, and Apple Container where supported. |
| [dotfiles/.zprofile](dotfiles/.zprofile) | Homebrew discovery and portable user/application paths. |
| [dotfiles/.zshrc](dotfiles/.zshrc) | Completions, history settings, rbenv, Starship, zoxide, and guarded eza/bat aliases. |
| [dotfiles/starship.toml](dotfiles/starship.toml) | Reviewed prompt layout with portable ASCII labels; no private context mappings. |
| [dotfiles/.gitconfig](dotfiles/.gitconfig) | Git LFS, pull preference, and a local identity/signing include. |
| [ghostty/config.ghostty](ghostty/config.ghostty) | Intentionally default settings, matching the empty live configuration. |
| [vscode/settings.json](vscode/settings.json) | Reviewed portable editor preferences, including Andromeda Italic and Material icons. |
| [vscode/keybindings.json](vscode/keybindings.json) | Empty custom overrides, matching the live file; Sublime bindings come from an extension. |
| [vscode/extensions.txt](vscode/extensions.txt) | The 45 installed extension IDs, managed only here. |
| [vscode/mcp.json](vscode/mcp.json) | Optional Docker-based Atlassian server with secure input prompts. |
| [node/global-packages.txt](node/global-packages.txt) | Forge CLI; blank lines and full-line comments are supported. |
| [macos/defaults.sh](macos/defaults.sh) | Optional matching Finder path/status bars and Dock preferences. |

Ghostty configuration goes to
`~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`.
Existing XDG Ghostty configuration can also be loaded by Ghostty; review it
separately if present. VS Code files go to
`~/Library/Application Support/Code/User/`, and Starship uses
`${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml`. Custom VS Code profiles are not
managed. The app-bundled VS Code CLI is found even when `code` is absent from `PATH`.

## Repeat Runs And Recovery

- Configuration files are copied, not newly symlinked into this checkout. Identical
  files are skipped. Differing existing files and dangling symlinks are preserved
  by default and reported at the end; a successful run does not mean they matched.
- `--replace-config` moves each conflict to a unique, private sibling directory,
  for example `~/.zshrc.backup.ABC12345/original`, before copying the new file.
  Backups are never reused. Symlink targets are not overwritten; directory
  destinations are rejected. Review backups locally because they may contain
  sensitive settings. Existing identical symlinks are left alone.
- To undo a replacement, close the relevant app, move the newly installed file
  aside, and move the backup's `original` back to the original destination.
  Do not restore through a symlink. Keep backups until the new setup is verified.
- Homebrew uses `brew bundle install --no-upgrade`. Installed formulae/casks are
  not deliberately upgraded; missing dependencies can still require dependency
  changes. npm packages and extensions are installed only when missing.
- Package/configuration errors stop setup with a nonzero exit status. Fix the
  reported issue and rerun. There is no whole-run rollback: packages and files
  completed before a failure stay installed.
- No uninstall, cleanup, Docker context switch, VM startup, service start, or app
  restart is requested. Application installers may still request permissions or
  install their own helpers. macOS preferences are changed only by explicit opt-in.

Homebrew Bundle can adopt manually installed applications. If a cask reports a
conflict with an existing app, font, or executable, inspect it and resolve it
manually; setup never uses `--force`. On the current Mac, check for duplicate native
and Homebrew Claude/Codex installations with `type -a claude codex` before choosing
one installation owner. Old tools and runtime directories are not removed.

## Manual Completion

### Shell And Runtimes

Open a new Ghostty window. Zsh is the expected login shell; select it in your macOS
account settings if necessary. Local additions belong in `~/.zprofile.local` and
`~/.zshrc.local`, which are sourced but never installed or overwritten. If you keep
an existing shell file, merge the new initialization and paths manually. Check
`type -a node npm code docker` to detect old PATH entries or runtime managers.

Homebrew owns Node, Python, Go, and Rust. npm CLIs use the user-owned prefix
`~/.local/share/npm`; its `bin` directory is added to the shell path. No `sudo npm`,
global Python pip installation, NVM initialization, or automatic Corepack setup
is performed. Use `uv` project environments for Python and `uv tool install` for
isolated Python CLIs; no global Python applications were found in the audit.

rbenv and ruby-build are installed, but no Ruby version is selected globally.
Install the version declared by each project's `.ruby-version`, using a maintained
Ruby release where compatible. The old local Ruby 3.1 and NVM Node installations
are not reproduced. Likewise, project SDKs, Rust targets, PHP, .NET SDKs, GCP CLI,
or package-manager versions are not inferred merely from installed extensions.

### Identity And Authentication

Set Git identity in a machine-local file after the managed Git configuration is installed:

```bash
git config --file "$HOME/.gitconfig.local" user.name "Your Name"
git config --file "$HOME/.gitconfig.local" user.email "you@example.com"
```

If your existing Git config was preserved, add the local include to it manually
or continue using your existing identity configuration. Do not put personal
identity or signing keys in the tracked template.

Sign into 1Password and explicitly enable its SSH agent and CLI integration if
you use them. Generate a new SSH key or authorize a key from your password manager;
never overwrite an existing private key. Register the public key with GitHub for
authentication and, separately, signing. Add `user.signingkey` to
`~/.gitconfig.local`, verify 1Password's `op-ssh-sign` is available, then enable
`commit.gpgsign` there. Signing is not enabled by the bootstrap because a fresh
machine has no configured signing identity. Complete GitHub CLI, cloud/SSO,
Forge, Claude, Codex, VS Code, and licensed-extension logins yourself.

Prefer password-manager integrations or secure app storage for credentials.
The shell optionally sources `~/.secrets`; if you use it, create it locally,
restrict it with `chmod 600 ~/.secrets`, and never export it into this repository.

### Docker, Services, And MCP

Open Docker Desktop, complete its first-launch permissions and applicable license
agreement, and wait for the engine to become ready. Verify `docker info` and
`docker compose version`. Setup does not start it or copy any Docker credentials,
contexts, images, volumes, or VM data.

Colima and monitoring tools require `--with-optional`. Start only what you need,
for example `colima start` or `brew services start prometheus`. Choose VM resources
for the new machine instead of restoring the old hard-coded allocation. Inspect
`docker context ls` and select the intended context explicitly when changing
runtimes. Prometheus and Grafana were running on the audited Mac; their private
configuration, data, and automatic startup are intentionally not reproduced.

For MCP, run setup with `--with-mcp`, then use VS Code's **MCP: List Servers** to
review and start the Atlassian server after Docker is ready. Site URLs, account
email, and API token are supplied through VS Code input prompts; the token is
masked and stored by VS Code, not in the repository. The template assumes one
Atlassian Cloud account/token for Jira and Confluence; adapt local inputs for
separate accounts or a different authentication method. Review server/tool trust
and token permissions before granting access. No blanket approvals are copied.
The image uses `latest`; pin a reviewed digest locally if immutable server
versions are required. Other extension-provided MCP servers require their own
setup and are not automatically trusted or started.

### macOS And Other Apps

The optional defaults enable Finder path/status bars, Dock autohide with zero
delay/animation, no recent apps, and a 52-point Dock. They overwrite only those
seven preferences on each explicit run. To undo, use System Settings/Finder or
`defaults delete` for a specific affected key to restore its system default.
No previous preference snapshot is saved. Log out/in when convenient; setup does
not kill Finder, Dock, or other apps. Keyboard and screenshot defaults are untouched.

Use employer self-service/MDM for VPN, security agents, SSO, Microsoft apps, and
corporate certificates. Personal/everyday apps are outside this manifest. Install
Orca from its vendor if needed; its sessions, agent skills/instructions, local
worktrees, and custom integrations are not copied. Restore project repositories
and application data separately from an approved backup.

## Maintenance And Verification

Fresh installs resolve maintained releases available at that time, not the exact
versions seen during the audit. Existing installs are preserved on reruns. Upgrade
deliberately with Homebrew, npm, and VS Code's update mechanisms, then revalidate.
For npm, retain the same `--prefix "$HOME/.local/share/npm"` on management commands.
Use project lockfiles/version declarations for project-level reproducibility.

Review inventory rather than blindly overwriting manifests:

```bash
brew leaves
brew list --cask
"/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" --list-extensions
npm list --global --prefix "$HOME/.local/share/npm" --depth=0
uv tool list
```

Edit the relevant manifest deliberately. A raw `brew bundle dump` can reintroduce
transitive packages, services, and duplicate extension management. Review editor
settings by allowlist; do not copy whole user directories or application plists.
Do not copy `.ssh`, cloud/kube/Docker auth files, `.npmrc`, editor history/storage,
machine paths, tenant IDs, workspace state, or credentials. Backups and local
override files are gitignored. Removing legacy files does not purge Git history;
rotate any credential ever committed and assess history cleanup separately.

Run the local validation suite (Python 3.11+ for the standard TOML parser):

```bash
bash tests/validate.sh
bash setup.sh --dry-run --with-optional --with-mcp --macos-defaults
```

Validation checks syntax, JSON/TOML and MCP references, manifest hygiene, selected
sensitive-data patterns, and isolated temporary-home tests. The latter cover
repeat runs, preserved files, distinct backups, symlinks, paths with spaces,
shell startup, optional operations, and simulated package/extension failures.
Homebrew parsing, Ghostty validation, Starship parsing, and ShellCheck run when
available; missing validation tools are reported. No real installers, defaults
writes, or service starts are used by these tests.

The automated tests do not prove fresh-machine downloads, app adoption, privileged
installer dialogs, Marketplace availability, logins, or a live MCP connection.
After installing on a new Mac, run `brew bundle check --file=Brewfile --no-upgrade`,
open Ghostty and VS Code, check your project builds, and complete the runtime and
authentication checks above. A disposable macOS VM or spare Mac is the remaining
end-to-end installation acceptance test.
