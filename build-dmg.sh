#!/bin/bash
set -e

cd "$(dirname "$0")"

APP="Clipster.app"
DMG_NAME="Clipster.dmg"
VOLUME_NAME="Clipster Installer"
TMP_DIR="$(mktemp -d)"
MOUNT_POINT="/Volumes/$VOLUME_NAME"

echo "Building app..."
./build-app.sh

echo "Preparing DMG contents..."
mkdir -p "$TMP_DIR"
cp -R "$APP" "$TMP_DIR/"

# Create Applications symlink
ln -s /Applications "$TMP_DIR/Applications"

# Remove existing DMG if any
rm -f "$DMG_NAME"

echo "Creating DMG..."
hdiutil create \
    -srcfolder "$TMP_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDZO \
    -o "$DMG_NAME" \
    -size 20m

echo "Cleaning up..."
rm -rf "$TMP_DIR"

echo "Done: $DMG_NAME"
