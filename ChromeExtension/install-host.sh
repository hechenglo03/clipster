#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$(cd "$SCRIPT_DIR/../Clipster.app/Contents/MacOS" && pwd)/Clipster"
HOSTS_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
MANIFEST="$SCRIPT_DIR/com.clipster.extension.json"

if [ ! -f "$APP_PATH" ]; then
    echo "Error: Clipster binary not found at $APP_PATH"
    exit 1
fi

mkdir -p "$HOSTS_DIR"

# 生成带绝对路径的 manifest
sed "s|HOST_PATH|$APP_PATH|g" "$MANIFEST" > "$HOSTS_DIR/com.clipster.extension.json"

echo "Native messaging host installed to:"
echo "$HOSTS_DIR/com.clipster.extension.json"
echo ""
echo "Next steps:"
echo "1. Open Chrome and go to chrome://extensions/"
echo "2. Enable Developer mode"
echo "3. Load unpacked extension from: $SCRIPT_DIR"
