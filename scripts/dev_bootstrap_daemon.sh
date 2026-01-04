#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-/Applications/SkyControl.app}"
PLIST_SRC="$APP_PATH/Contents/Library/LaunchDaemons/com.skynet.selfcontrold.plist"
DAEMON_SRC="$APP_PATH/Contents/Resources/com.skynet.selfcontrold"

PLIST_DST="/Library/LaunchDaemons/com.skynet.selfcontrold.plist"
DAEMON_DST="/Library/PrivilegedHelperTools/com.skynet.selfcontrold"
DEV_FLAG="/Library/PrivilegedHelperTools/com.skynet.selfcontrold.dev"

if [[ ! -f "$PLIST_SRC" ]]; then
  echo "Missing plist: $PLIST_SRC"
  echo "Build and install the app to /Applications first."
  exit 1
fi

if [[ ! -f "$DAEMON_SRC" ]]; then
  echo "Missing daemon binary: $DAEMON_SRC"
  exit 1
fi

echo "Installing daemon for dev testing (root-owned locations)..."
sudo cp "$DAEMON_SRC" "$DAEMON_DST"
sudo cp "$PLIST_SRC" "$PLIST_DST"
sudo touch "$DEV_FLAG"

# Point plist at the root-owned daemon location.
sudo /usr/bin/plutil -replace ProgramArguments -json "[\"$DAEMON_DST\"]" "$PLIST_DST"

# Required permissions for LaunchDaemons.
sudo chown root:wheel "$DAEMON_DST" "$PLIST_DST"
sudo chown root:wheel "$DEV_FLAG"
sudo chmod 755 "$DAEMON_DST"
sudo chmod 644 "$PLIST_DST"
sudo chmod 644 "$DEV_FLAG"

echo "Bootstrapping daemon from: $PLIST_DST"
sudo launchctl bootout system/com.skynet.selfcontrold >/dev/null 2>&1 || true
sudo launchctl bootstrap system "$PLIST_DST"
sudo launchctl enable system/com.skynet.selfcontrold
sudo launchctl kickstart -k system/com.skynet.selfcontrold

echo "Status:"
sudo launchctl print system/com.skynet.selfcontrold | head -n 40
