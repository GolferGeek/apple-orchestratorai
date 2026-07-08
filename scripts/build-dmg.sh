#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Apple Orchestrator AI"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"

echo "Apple Orchestrator AI DMG build scaffold"
echo "root: $ROOT_DIR"

if [ ! -d "$ROOT_DIR/$APP_NAME.app" ] && [ ! -d "$BUILD_DIR/$APP_NAME.app" ]; then
  echo "No app bundle found yet."
  echo "Expected one of:"
  echo "  $ROOT_DIR/$APP_NAME.app"
  echo "  $BUILD_DIR/$APP_NAME.app"
  echo ""
  echo "This script is a packaging entry point for the future Swift app target."
  exit 0
fi

mkdir -p "$DIST_DIR"

APP_PATH="$BUILD_DIR/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
  APP_PATH="$ROOT_DIR/$APP_NAME.app"
fi

DMG_PATH="$DIST_DIR/apple-orchestrator-ai.dmg"

echo "Packaging: $APP_PATH"
echo "Output: $DMG_PATH"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "done: $DMG_PATH"
