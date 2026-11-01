#!/bin/sh
# Removes everything install.sh added and turns sleep back on.
HELPER_DIR=/usr/local/libexec/sleep-guard
APP="$HOME/Applications/SleepGuard.app"
SHARE="$HOME/.local/share/sleep-guard"
LABEL=io.github.tedkim81.sleep-guard
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

# Stop here if sudo fails: removing the indicator and functions while sleep may still be
# disabled would leave a setting nobody can see or turn off.
if [ -x "$HELPER_DIR/sleepguard.sh" ]; then
  if ! sudo "$HELPER_DIR/sleepguard.sh" stop || ! sudo rm -rf "$HELPER_DIR"; then
    echo "sudo failed; aborting. Run ./uninstall.sh again." >&2
    exit 1
  fi
fi

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
pkill -x SleepGuard 2>/dev/null
rm -rf "$PLIST" "$APP" "$SHARE"

# Write back through `cat >` rather than `sed -i`, so a symlinked .zshrc (dotfiles) stays a symlink
if [ -f "$ZSHRC" ]; then
  tmp=$(mktemp)
  sed -e '/^# Sleep Guard: awake \/ unawake \/ screenoff$/d' -e '/sleep-guard\/awake\.zsh/d' "$ZSHRC" > "$tmp" &&
    cat "$tmp" > "$ZSHRC"
  rm -f "$tmp"
fi

echo "Sleep Guard removed. Open a new terminal to drop the awake/unawake functions."
