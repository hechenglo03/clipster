import AppKit
import Carbon

final class KeyPanelWindow: NSPanel {
    weak var keyDelegate: PanelController?

    override func keyDown(with event: NSEvent) {
        if keyDelegate?.handleKeyDown(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        keyDelegate?.hide()
    }
}

final class PanelController: NSWindowController, NSWindowDelegate {
    let listController: ClipListViewController
    private let pasteSimulator: PasteSimulator
    private let repository: ItemRepository
    private var selected: ClipItem?
    private var previousApp: NSRunningApplication?

    init(_ repository: ItemRepository, _ searchService: SearchService, _ groupRepository: GroupRepository, _ pasteSimulator: PasteSimulator) {
        self.repository = repository
        self.pasteSimulator = pasteSimulator
        self.listController = ClipListViewController(repository, searchService, groupRepository)

        let panel = KeyPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Clipster"
        panel.titlebarAppearsTransparent = false
        panel.titleVisibility = .visible
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = NSColor(srgbRed: 0.07, green: 0.07, blue: 0.08, alpha: 0.98)
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.minSize = NSSize(width: 640, height: 420)
        panel.contentMinSize = NSSize(width: 640, height: 420)

        super.init(window: panel)
        panel.keyDelegate = self
        panel.delegate = self
        contentViewController = listController
        listController.delegate = self
        centerOnScreen()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        guard let panel = window else { return }
        NSLog("[Clipster] PanelController.show called")
        previousApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        listController.reloadData()
        centerOnScreen()
        panel.makeKeyAndOrderFront(nil)
        NSLog("[Clipster] Panel ordered front, visible=%d", panel.isVisible)
    }

    func hide() {
        NSLog("[Clipster] PanelController.hide called")
        window?.orderOut(nil)
    }

    func toggle() {
        NSLog("[Clipster] PanelController.toggle called visible=%d", window?.isVisible == true ? 1 : 0)
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let mods = event.modifierFlags

        if keyCode == UInt16(kVK_Escape) {
            hide()
            return true
        }

        if keyCode == UInt16(kVK_Return) {
            NSLog("[Clipster] Return pressed, selected=%@", selected != nil ? "yes" : "no")
            pasteSelected()
            return true
        }

        if keyCode == UInt16(kVK_Delete) {
            deleteSelected()
            return true
        }

        if keyCode == UInt16(kVK_DownArrow) {
            listController.moveSelection(1)
            return true
        }

        if keyCode == UInt16(kVK_UpArrow) {
            listController.moveSelection(-1)
            return true
        }

        if mods.contains(.command) {
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
            switch key {
            case "d":
                favoriteSelected()
                return true
            case "g":
                if let item = selected {
                    listController.showAddToGroupSheet(for: item)
                }
                return true
            case "1"..."8":
                if let num = Int(key) {
                    listController.selectCategoryIndex(num - 1)
                    return true
                }
            default: break
            }
        }

        if let chars = event.characters, !chars.isEmpty, !mods.contains(.command) {
            if let digit = chars.first, digit.isNumber {
                listController.selectIndex(Int(String(digit))! - 1)
                pasteSelected()
                return true
            }
            if chars == "/" {
                listController.focusSearchField()
                return true
            }
        }

        return false
    }

    private func pasteSelected() {
        guard let item = selected else {
            NSLog("[Clipster] pasteSelected: no item selected")
            return
        }
        NSLog("[Clipster] pasteSelected: %@", item.content)
        let target = previousApp
        hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.pasteSimulator.paste(item, to: target)
        }
    }

    private func deleteSelected() {
        guard let item = selected, let id = item.id else { return }
        repository.delete(id: id)
        selected = nil
        listController.reloadData()
    }

    private func favoriteSelected() {
        guard let item = selected, let id = item.id else { return }
        repository.toggleFavorite(id: id)
        listController.reloadData()
    }

    private func centerOnScreen() {
        guard let panel = window, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let w: CGFloat = 800
        let h: CGFloat = 540
        let x = frame.midX - w / 2
        let y = frame.maxY - 40 - h
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }
}

extension PanelController: ClipListDelegate {
    func didClickItem(_ item: ClipItem) {
        selected = item
        pasteSelected()
    }

    func didHighlightItem(_ item: ClipItem) {
        selected = item
    }

    func didToggleFavorite(_ item: ClipItem) {
        guard let id = item.id else { return }
        repository.toggleFavorite(id: id)
        listController.reloadData()
    }

    func didDeleteItem(_ item: ClipItem) {
        guard let id = item.id else { return }
        repository.delete(id: id)
        listController.reloadData()
    }

    func windowWillClose(_ notification: Notification) {
        hide()
    }
}
