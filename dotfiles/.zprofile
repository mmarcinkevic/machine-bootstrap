if command -v brew >/dev/null 2>&1; then
	eval "$(brew shellenv)"
else
	for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew "$HOME/homebrew/bin/brew"; do
		if [[ -x "$brew_bin" ]]; then
			eval "$("$brew_bin" shellenv)"
			break
		fi
	done
	unset brew_bin
fi

typeset -U path PATH
path=(
	"$HOME/.local/share/npm/bin"
	"$HOME/.local/bin"
	"$HOME/.rbenv/bin"
	"$HOME/.cargo/bin"
	"$HOME/go/bin"
	'/Applications/Visual Studio Code.app/Contents/Resources/app/bin'
	'/Applications/Ghostty.app/Contents/MacOS'
	$path
)

if [[ -f "$HOME/.zprofile.local" ]]; then
	source "$HOME/.zprofile.local"
fi
