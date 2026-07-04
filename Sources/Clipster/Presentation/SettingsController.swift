import AppKit
import Carbon

final class SettingsController: NSWindowController, NSTextFieldDelegate {
    private let repository: ItemRepository
    private var bindings: [String: HotkeyBinding] = [:]
    private var recordingField: String?

    init(_ repository: ItemRepository) {
        self.repository = repository
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Clipster 设置"
        win.appearance = NSAppearance(named: .darkAqua)
        win.backgroundColor = Theme.bg
        win.isReleasedWhenClosed = false
        win.center()
        super.init(window: win)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Theme.bg.cgColor

        let title = NSTextField(labelWithString: "自定义快捷键")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = Theme.text
        title.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(title)

        let tip = NSTextField(labelWithString: "点击按键组合可重新录制 · 支持修饰键 + 任意按键")
        tip.font = .systemFont(ofSize: 11)
        tip.textColor = Theme.textFaint
        tip.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tip)

        let actions: [(String, String)] = [
            ("show", "唤出主窗口"),
            ("paste", "直接粘贴上一条"),
            ("search", "快速搜索"),
            ("favorite", "新建收藏"),
        ]

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        for (action, label) in actions {
            let row = makeRow(action: action, label: label)
            stack.addArrangedSubview(row)
        }

        let clearBtn = NSButton(title: "清理 30 天前记录", target: self, action: #selector(clearOld))
        clearBtn.translatesAutoresizingMaskIntoConstraints = false
        clearBtn.bezelStyle = .rounded
        contentView.addSubview(clearBtn)

        let countLabel = NSTextField(labelWithString: "当前 \(repository.count()) 条记录")
        countLabel.font = .systemFont(ofSize: 12)
        countLabel.textColor = Theme.textFaint
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.tag = 100
        contentView.addSubview(countLabel)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            tip.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            tip.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            stack.topAnchor.constraint(equalTo: tip.bottomAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            clearBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            clearBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            countLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28),
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
        ])
    }

    private func makeRow(action: String, label: String) -> NSView {
        let row = NSView()
        row.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 14)
        lbl.textColor = Theme.textDim
        lbl.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(lbl)

        let field = RecordableKeyField()
        field.actionName = action
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false
        field.wantsLayer = true
        field.layer?.cornerRadius = 6
        field.layer?.backgroundColor = Theme.surface3.cgColor
        field.focusRingType = .none
        field.alignment = .center
        field.font = .systemFont(ofSize: 13, weight: .medium)
        field.textColor = Theme.text
        field.stringValue = HotkeyManager.shared.bindingString(for: action)
        field.widthAnchor.constraint(equalToConstant: 120).isActive = true
        row.addSubview(field)

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            field.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            field.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            field.heightAnchor.constraint(equalToConstant: 28),
        ])
        return row
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        return false
    }

    @objc private func clearOld() {
        repository.clearAll(olderThan: 30, keepCount: 1000)
        if let label = window?.contentView?.viewWithTag(100) as? NSTextField {
            label.stringValue = "当前 \(repository.count()) 条记录"
        }
    }
}

final class RecordableKeyField: NSTextField {
    var actionName: String = ""
    private var isRecording = false

    override func keyDown(with event: NSEvent) {
        if isRecording {
            record(event)
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isRecording {
            record(event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        layer?.backgroundColor = Theme.accent.withAlphaComponent(0.2).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Theme.accent.withAlphaComponent(0.5).cgColor
        stringValue = "录制中..."
        textColor = Theme.accent
    }

    private func record(_ event: NSEvent) {
        let keyCode = event.keyCode
        var carbonFlags: UInt32 = 0
        if event.modifierFlags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if event.modifierFlags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if event.modifierFlags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.command) { carbonFlags |= UInt32(cmdKey) }

        let binding = HotkeyBinding(keyCode: UInt32(keyCode), modifiers: carbonFlags)
        HotkeyManager.shared.updateBinding(action: actionName, binding: binding)
        stringValue = HotkeyManager.modifiersString(carbonFlags) + HotkeyManager.keyCodeString(UInt32(keyCode))
        textColor = Theme.text
        isRecording = false
        layer?.borderWidth = 0
        layer?.backgroundColor = Theme.surface3.cgColor
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if isRecording {
            isRecording = false
            layer?.borderWidth = 0
            layer?.backgroundColor = Theme.surface3.cgColor
            textColor = Theme.text
            stringValue = HotkeyManager.shared.bindingString(for: actionName)
        }
        return result
    }
}
