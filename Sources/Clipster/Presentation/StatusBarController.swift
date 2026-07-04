import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private var onShow: (() -> Void)?
    private var onQuit: (() -> Void)?
    private var onSettings: (() -> Void)?
    private var onOpenPermissions: (() -> Void)?
    private var permissionItem: NSMenuItem?

    init(onShow: @escaping () -> Void, onSettings: @escaping () -> Void, onQuit: @escaping () -> Void, onOpenPermissions: @escaping () -> Void) {
        self.onShow = onShow
        self.onSettings = onSettings
        self.onQuit = onQuit
        self.onOpenPermissions = onOpenPermissions
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSLog("[Clipster] StatusBarController init")
        setupMenu()
    }

    private func setupMenu() {
        statusItem.length = NSStatusItem.variableLength
        if let button = statusItem.button {
            let iconPath = ("~" as NSString).expandingTildeInPath + "/Downloads/clipster.png"
            if let img = NSImage(contentsOfFile: iconPath) {
                img.isTemplate = true
                img.size = NSSize(width: 18, height: 18)
                button.image = img
            } else {
                let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipster")
                if let img = image {
                    img.isTemplate = true
                    img.size = NSSize(width: 18, height: 18)
                    button.image = img
                } else {
                    button.title = "Clip"
                }
            }
            button.toolTip = "Clipster"
        }

        let menu = NSMenu()
        menu.addItem(makeItem("显示 Clipster", "v", #selector(showPanel)))
        menu.addItem(.separator())

        let permItem = NSMenuItem(title: "", action: #selector(openPermissions), keyEquivalent: "")
        permItem.target = self
        permItem.isHidden = true
        menu.addItem(permItem)
        permissionItem = permItem
        menu.addItem(.separator())

        menu.addItem(makeItem("设置...", "s", #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(makeItem("退出 Clipster", "q", #selector(quit)))
        statusItem.menu = menu
    }

    private func makeItem(_ title: String, _ key: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.keyEquivalentModifierMask = .command
        return item
    }

    @objc private func showPanel() { onShow?() }
    @objc private func openSettings() { onSettings?() }
    @objc private func quit() { onQuit?() }
    @objc private func openPermissions() { onOpenPermissions?() }

    func setAccessibilityWarning(_ warning: Bool, message: String? = nil) {
        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                if warning {
                    button.toolTip = message ?? "Clipster（快捷键未授权）"
                    button.appearsDisabled = true
                } else {
                    button.toolTip = "Clipster"
                    button.appearsDisabled = false
                }
            }

            if let item = self.permissionItem {
                item.isHidden = !warning
                item.title = message ?? "⚠️ 快捷键未授权，点击打开系统设置"
            }
        }
    }
}
