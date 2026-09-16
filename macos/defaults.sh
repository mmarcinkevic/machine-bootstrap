#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == Darwin && "$EUID" -ne 0 ]] || { printf 'Run on macOS as your normal user.\n' >&2; exit 1; }

defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 52

printf 'Finder and Dock preferences applied. Log out and back in when convenient.\n'
