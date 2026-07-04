#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building Clipster..."
swiftc \
  Sources/Clipster/Models/Category.swift \
  Sources/Clipster/Models/ClipItem.swift \
  Sources/Clipster/Data/Database.swift \
  Sources/Clipster/Data/ItemRepository.swift \
  Sources/Clipster/Domain/ContentClassifier.swift \
  Sources/Clipster/Domain/Deduplicator.swift \
  Sources/Clipster/Domain/ClipboardWatcher.swift \
  Sources/Clipster/Domain/SearchService.swift \
  Sources/Clipster/OSBridge/HotkeyManager.swift \
  Sources/Clipster/OSBridge/PasteSimulator.swift \
  Sources/Clipster/OSBridge/Permissions.swift \
  Sources/Clipster/Presentation/Theme.swift \
  Sources/Clipster/Presentation/ClipCollectionViewItem.swift \
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

echo "Build succeeded: $(./Clipster --version 2>/dev/null || echo 'Clipster 1.0') ($(du -h Clipster | cut -f1))"
echo "Run: ./Clipster"
