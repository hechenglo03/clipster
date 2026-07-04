#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="Clipster.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Compiling..."
swiftc \
  Sources/Clipster/Models/Category.swift \
  Sources/Clipster/Models/ClipItem.swift \
  Sources/Clipster/Models/ClipGroup.swift \
  Sources/Clipster/Data/Database.swift \
  Sources/Clipster/Data/ItemRepository.swift \
  Sources/Clipster/Data/GroupRepository.swift \
  Sources/Clipster/Domain/ContentClassifier.swift \
  Sources/Clipster/Domain/Deduplicator.swift \
  Sources/Clipster/Domain/ClipboardWatcher.swift \
  Sources/Clipster/Domain/SearchService.swift \
  Sources/Clipster/OSBridge/HotkeyManager.swift \
  Sources/Clipster/OSBridge/PasteSimulator.swift \
  Sources/Clipster/OSBridge/Permissions.swift \
  Sources/Clipster/NativeMessaging/NativeMessagingHost.swift \
  Sources/Clipster/Presentation/Theme.swift \
  Sources/Clipster/Presentation/CategoryButton.swift \
  Sources/Clipster/Presentation/ClipCollectionViewItem.swift \
  Sources/Clipster/Presentation/ImageCollectionViewItem.swift \
  Sources/Clipster/Presentation/ClipListViewController.swift \
  Sources/Clipster/Presentation/PanelController.swift \
  Sources/Clipster/Presentation/StatusBarController.swift \
  Sources/Clipster/Presentation/SettingsController.swift \
  Sources/Clipster/App/AppDelegate.swift \
  Sources/Clipster/App/main.swift \
  -o Clipster \
  -framework AppKit -framework Carbon -framework CryptoKit \
  -lsqlite3 \
  -target x86_64-apple-macos11.0

mkdir -p "$MACOS" "$RESOURCES"
cp Clipster "$MACOS/Clipster"

codesign --force --deep --sign - "$APP" 2>/dev/null || true

if [ ! -f "$CONTENTS/Info.plist" ]; then
  cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Clipster</string>
    <key>CFBundleDisplayName</key>
    <string>Clipster</string>
    <key>CFBundleIdentifier</key>
    <string>com.clipster.app.v2</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Clipster</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST
fi

echo "Built: $APP"
echo "Launch: open $APP"
