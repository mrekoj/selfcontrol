#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-debug}"
APP_NAME="SelfControl"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LAUNCHD_DIR="$CONTENTS_DIR/Library/LaunchDaemons"

BIN_PATH="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIG/SelfControlApp"
INFO_PLIST_SRC="$ROOT_DIR/Sources/SelfControlApp/Resources/AppInfo.plist"
LAUNCHD_PLIST_SRC="$ROOT_DIR/Sources/SelfControlApp/Resources/LaunchDaemons/com.skynet.selfcontrold.plist"
ICON_SRC="$ROOT_DIR/SelfControlIcon.icns"

mkdir -p "$BUILD_DIR"

swift build -c "$CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$LAUNCHD_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp "$INFO_PLIST_SRC" "$CONTENTS_DIR/Info.plist"

if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$RESOURCES_DIR/SelfControlIcon.icns"
fi

cp "$LAUNCHD_PLIST_SRC" "$LAUNCHD_DIR/com.skynet.selfcontrold.plist"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

echo "Built: $APP_DIR"
