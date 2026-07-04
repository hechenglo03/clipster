import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var database: Database!
    private var repository: ItemRepository!
    private var searchService: SearchService!
    private var deduplicator: Deduplicator!
    private var clipboardWatcher: ClipboardWatcher!
    private var pasteSimulator: PasteSimulator!
    private var cleanupTimer: Timer?
    private var panelController: PanelController!
    private var settingsController: SettingsController!
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[Clipster] applicationDidFinishLaunching started")
        do {
            database = try Database(path: Database.defaultPath())
        } catch {
            NSLog("[Clipster] Database init failed: \(error)")
            return
        }
        NSLog("[Clipster] Database OK")
        repository = ItemRepository(database)
        searchService = SearchService(repository)
        deduplicator = Deduplicator(repository)
        pasteSimulator = PasteSimulator()
        clipboardWatcher = ClipboardWatcher(repository, deduplicator)
        clipboardWatcher.onNewItem = { [weak self] _ in
            self?.panelController.reloadDataIfVisible()
        }
        clipboardWatcher.start()
        NSLog("[Clipster] ClipboardWatcher started")

        let groupRepository = GroupRepository(database)
        panelController = PanelController(repository, searchService, groupRepository, pasteSimulator)
        settingsController = SettingsController(repository)
        NSLog("[Clipster] Panel & Settings created")

        statusBarController = StatusBarController(
            onShow: { [weak self] in self?.panelController.toggle() },
            onSettings: { [weak self] in self?.settingsController.showWindow(nil) },
            onQuit: { NSApp.terminate(nil) },
            onOpenPermissions: { Permissions.openInputMonitoringPrefs() }
        )
        NSLog("[Clipster] StatusBar created")

        setupHotkeys()
        NSLog("[Clipster] Hotkeys setup done")

        // 启动时检查辅助功能/输入监控权限。若未授权，弹出系统提示并打开设置页面；
        // 授权后需要重新启动 HotkeyManager 才能让全局快捷键生效。
        if !HotkeyManager.shared.isRunning {
            NSLog("[Clipster] Hotkeys failed to start")
            Permissions.requestAccessibility()
            Permissions.openInputMonitoringPrefs()
            showPermissionAlert()
            statusBarController.setAccessibilityWarning(true, message: "⚠️ 需要系统权限，点击打开系统设置")
            // 用户授权后，轮询重试启动监听
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.retryStartHotkeysIfNeeded(attempts: 10)
            }
        } else {
            NSLog("[Clipster] Hotkeys running")
            statusBarController.setAccessibilityWarning(false)
        }

        NSApp.setActivationPolicy(.accessory)

        // 启动时执行一次清理，并每小时执行一次，只保留最近 7 天数据
        runCleanup()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.runCleanup()
        }

        NSLog("[Clipster] Started with \(repository.count()) records")
    }

    private func runCleanup() {
        let before = repository.count()
        repository.cleanup(retentionDays: 7)
        let after = repository.count()
        if before != after {
            NSLog("[Clipster] Cleaned up %d old records, remaining %d", before - after, after)
            panelController.reloadDataIfVisible()
        }
    }

    private func setupHotkeys() {
        let hm = HotkeyManager.shared
        hm.register(action: "show", binding: .defaultShow) { [weak self] in
            self?.panelController.toggle()
        }
        hm.register(action: "paste", binding: .defaultPaste) { [weak self] in
            self?.pasteLast()
        }
        hm.register(action: "search", binding: .defaultSearch) { [weak self] in
            self?.panelController.show()
            self?.panelController.focusSearch()
        }
        hm.register(action: "favorite", binding: .defaultFavorite) { [weak self] in
            self?.favoriteLast()
        }
        hm.start()
        updateHotkeyWarning()
    }

    private func updateHotkeyWarning() {
        if HotkeyManager.shared.isRunning {
            statusBarController.setAccessibilityWarning(false)
        } else {
            let msg = HotkeyManager.shared.lastError ?? "⚠️ 全局快捷键未启动，点击打开系统设置开启权限"
            statusBarController.setAccessibilityWarning(true, message: msg)
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要系统权限"
        alert.informativeText = "Clipster 的全局快捷键需要以下权限之一：\n\n1. 系统设置 → 隐私与安全性 → 输入监控 → 添加并勾选 Clipster\n2. 系统设置 → 隐私与安全性 → 辅助功能 → 添加并勾选 Clipster\n\n授权后可能需要重启 Clipster。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn {
            Permissions.openInputMonitoringPrefs()
        }
    }

    private func pasteLast() {
        let items = repository.fetchAll(limit: 1)
        guard let item = items.first else { return }
        let target = NSWorkspace.shared.frontmostApplication
        pasteSimulator.paste(item, to: target)
    }

    private func favoriteLast() {
        let items = repository.fetchAll(limit: 1)
        guard let item = items.first, let id = item.id else { return }
        repository.toggleFavorite(id: id)
        panelController.reloadDataIfVisible()
    }

    private func retryStartHotkeysIfNeeded(attempts: Int = 10) {
        guard attempts > 0 else {
            updateHotkeyWarning()
            return
        }
        HotkeyManager.shared.stop()
        HotkeyManager.shared.start()
        updateHotkeyWarning()
        if HotkeyManager.shared.isRunning {
            NSLog("[Clipster] Hotkeys restarted after permission grant")
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.retryStartHotkeysIfNeeded(attempts: attempts - 1)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher.stop()
        HotkeyManager.shared.stop()
        cleanupTimer?.invalidate()
    }
}

extension PanelController {
    func reloadDataIfVisible() {
        if window?.isVisible == true {
            listController.reloadData()
        }
    }

    func focusSearch() {
        listController.focusSearchField()
    }
}
