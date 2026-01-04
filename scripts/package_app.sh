#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-debug}"
APP_NAME="SkyControl"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
LAUNCHD_DIR="$CONTENTS_DIR/Library/LaunchDaemons"

BIN_PATH="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIG/SelfControlApp"
DAEMON_BIN="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIG/selfcontrold"
CLI_BIN="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIG/selfcontrol-cli"
INFO_PLIST_SRC="$ROOT_DIR/Sources/SelfControlApp/Resources/AppInfo.plist"
LAUNCHD_PLIST_SRC="$ROOT_DIR/Sources/SelfControlApp/Resources/LaunchDaemons/com.skynet.selfcontrold.plist"
ICON_SRC="$ROOT_DIR/SelfControlIcon.icns"
SPARKLE_SRC="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIG/Sparkle.framework"

mkdir -p "$BUILD_DIR"

swift build -c "$CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$LAUNCHD_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
if [[ -f "$CLI_BIN" ]]; then
  cp "$CLI_BIN" "$MACOS_DIR/selfcontrol-cli"
fi
cp "$INFO_PLIST_SRC" "$CONTENTS_DIR/Info.plist"

if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$RESOURCES_DIR/SelfControlIcon.icns"
fi

cp "$LAUNCHD_PLIST_SRC" "$LAUNCHD_DIR/com.skynet.selfcontrold.plist"
if [[ -f "$DAEMON_BIN" ]]; then
  cp "$DAEMON_BIN" "$RESOURCES_DIR/com.skynet.selfcontrold"
fi

# Patch LaunchDaemon plist to use absolute path (expected install location).
ABS_DAEMON="/Applications/$APP_NAME.app/Contents/Resources/com.skynet.selfcontrold"
if [[ -f "$LAUNCHD_DIR/com.skynet.selfcontrold.plist" ]]; then
  /usr/bin/plutil -replace ProgramArguments -json "[\"$ABS_DAEMON\"]" "$LAUNCHD_DIR/com.skynet.selfcontrold.plist"
fi

if [[ -d "$SPARKLE_SRC" ]]; then
  cp -R "$SPARKLE_SRC" "$FRAMEWORKS_DIR/Sparkle.framework"
fi

# Ensure rpath includes Frameworks so Sparkle can be loaded
if command -v otool >/dev/null 2>&1; then
  if ! otool -l "$MACOS_DIR/$APP_NAME" | rg -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"
  fi
fi

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  if [[ -f "$RESOURCES_DIR/com.skynet.selfcontrold" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$RESOURCES_DIR/com.skynet.selfcontrold"
  fi
  if [[ -f "$MACOS_DIR/selfcontrol-cli" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$MACOS_DIR/selfcontrol-cli"
  fi
  if [[ -d "$FRAMEWORKS_DIR/Sparkle.framework" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$FRAMEWORKS_DIR/Sparkle.framework"
  fi
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
else
  # Ad-hoc sign for local runs after install_name_tool modifies rpaths.
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "Built: $APP_DIR"
