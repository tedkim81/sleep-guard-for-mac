#!/bin/sh
# Installs Sleep Guard for the current user.
set -e
cd "$(dirname "$0")"

HELPER_DIR=/usr/local/libexec/sleep-guard
APP="$HOME/Applications/SleepGuard.app"
SHARE="$HOME/.local/share/sleep-guard"
LABEL=io.github.tedkim81.sleep-guard
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

[ "$(uname)" = Darwin ] || { echo "Sleep Guard runs on macOS only." >&2; exit 1; }
xcode-select -p >/dev/null 2>&1 || { echo "Command Line Tools are required: xcode-select --install" >&2; exit 1; }

# The helper runs as root, so no directory on its path may be writable by anyone else.
for d in /usr/local /usr/local/libexec; do
  [ -e "$d" ] || continue
  if [ "$(stat -f %u "$d")" != 0 ] || [ -n "$(find "$d" -maxdepth 0 -perm +022)" ]; then
    echo "$d must be owned by root and not group/world-writable to hold a root helper." >&2
    exit 1
  fi
done

echo "==> Building the menu bar app"
mkdir -p "$APP/Contents/MacOS"
clang -O2 -fobjc-arc -framework AppKit app/SleepGuard.m -o "$APP/Contents/MacOS/SleepGuard"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$LABEL</string>
  <key>CFBundleName</key><string>SleepGuard</string>
  <key>CFBundleExecutable</key><string>SleepGuard</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"

echo "==> Installing the root helper to $HELPER_DIR (sudo)"
sudo install -d -o root -g wheel -m 755 /usr/local/libexec "$HELPER_DIR"
sudo install -o root -g wheel -m 755 bin/sleepguard.sh "$HELPER_DIR/sleepguard.sh"

echo "==> Installing shell functions"
mkdir -p "$SHARE"
cp shell/awake.zsh "$SHARE/awake.zsh"
if ! grep -qs 'sleep-guard/awake.zsh' "$ZSHRC"; then
  printf '\n# Sleep Guard: awake / unawake / screenoff\nsource "$HOME/.local/share/sleep-guard/awake.zsh"\n' >> "$ZSHRC"
fi

echo "==> Registering the login check"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- Runs SleepGuard once at login. The app quits immediately if sleep is enabled.
     It runs the executable directly (not via /usr/bin/open) so System Settings lists it as SleepGuard. -->
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP/Contents/MacOS/SleepGuard</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo
echo "Done. Open a new terminal (or run: source $ZSHRC) and try: awake 2m"
