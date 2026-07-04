import Foundation
import AppKit
import Carbon

struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultShow = HotkeyBinding(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(controlKey | cmdKey))
    static let defaultPaste = HotkeyBinding(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey))
    static let defaultSearch = HotkeyBinding(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey))
    static let defaultFavorite = HotkeyBinding(keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(controlKey))
}

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var registrations: [(action: String, binding: HotkeyBinding)] = []
    private var handlers: [String: () -> Void] = [:]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?

    private(set) var isRunning = false
    private(set) var lastError: String?

    private init() {
        loadDefaults()
    }

    func register(action: String, binding: HotkeyBinding, handler: @escaping () -> Void) {
        handlers[action] = handler
        if let idx = registrations.firstIndex(where: { $0.action == action }) {
            registrations[idx].binding = binding
        } else {
            registrations.append((action, binding))
        }
    }

    func updateBinding(action: String, binding: HotkeyBinding) {
        if let idx = registrations.firstIndex(where: { $0.action == action }) {
            registrations[idx].binding = binding
        } else {
            registrations.append((action, binding))
        }
        if isRunning {
            stop()
            start()
        }
    }

    func start() {
        guard !isRunning else { return }

        lastError = nil

        // 优先尝试 CGEventTap（需要输入监控权限，更可靠）
        if startEventTap() {
            isRunning = true
            NSLog("[HotkeyManager] CGEventTap started with %d hotkeys", registrations.count)
            return
        }

        // 降级到 NSEvent global monitor（需要辅助功能权限）
        if startGlobalMonitor() {
            isRunning = true
            NSLog("[HotkeyManager] Global monitor started with %d hotkeys", registrations.count)
            return
        }

        lastError = "需要系统权限：请前往 系统设置 → 隐私与安全性 → 辅助功能/输入监控，开启 Clipster。"
        NSLog("[HotkeyManager] Failed to start any hotkey listener")
    }

    private func startEventTap() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let info = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, info in
                let me = Unmanaged<HotkeyManager>.fromOpaque(info!).takeUnretainedValue()
                return me.handleEvent(event)
            },
            userInfo: info
        ) else {
            NSLog("[HotkeyManager] CGEvent.tapCreate failed (Input Monitoring permission may be required)")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func startGlobalMonitor() -> Bool {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleNSEvent(event)
        }
        let ok = globalMonitor != nil
        if !ok {
            NSLog("[HotkeyManager] Global monitor requires Accessibility permission")
        }
        return ok
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        isRunning = false
        NSLog("[HotkeyManager] Stopped")
    }

    func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard event.type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let carbonFlags = convertFlags(event.flags)

        for (action, binding) in registrations {
            if binding.keyCode == keyCode && binding.modifiers == carbonFlags {
                NSLog("[HotkeyManager] matched action=%@", action)
                if let handler = handlers[action] {
                    DispatchQueue.main.async { handler() }
                }
                return nil
            }
        }
        return Unmanaged.passRetained(event)
    }

    private func handleNSEvent(_ event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        let carbonFlags = convertNSEventModifiers(event.modifierFlags)
        NSLog("[HotkeyManager] global monitor keyCode=%d carbonFlags=%d", keyCode, carbonFlags)

        for (action, binding) in registrations {
            if binding.keyCode == keyCode && binding.modifiers == carbonFlags {
                NSLog("[HotkeyManager] global monitor matched action=%@", action)
                if let handler = handlers[action] {
                    DispatchQueue.main.async { handler() }
                }
            }
        }
    }

    private func convertFlags(_ flags: CGEventFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.maskControl) { result |= UInt32(controlKey) }
        if flags.contains(.maskAlternate) { result |= UInt32(optionKey) }
        if flags.contains(.maskShift) { result |= UInt32(shiftKey) }
        if flags.contains(.maskCommand) { result |= UInt32(cmdKey) }
        return result
    }

    private func convertNSEventModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }

    private func loadDefaults() {
        registrations = [
            ("show", .defaultShow),
            ("paste", .defaultPaste),
            ("search", .defaultSearch),
            ("favorite", .defaultFavorite),
        ]
    }

    static func keyCodeString(_ keyCode: UInt32) -> String {
        let mapping: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9", UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩",
        ]
        return mapping[keyCode] ?? "Key\(keyCode)"
    }

    static func modifiersString(_ mods: UInt32) -> String {
        var s = ""
        if mods & UInt32(cmdKey) != 0 { s += "⌘" }
        if mods & UInt32(controlKey) != 0 { s += "⌃" }
        if mods & UInt32(optionKey) != 0 { s += "⌥" }
        if mods & UInt32(shiftKey) != 0 { s += "⇧" }
        return s
    }

    func bindingString(for action: String) -> String {
        guard let reg = registrations.first(where: { $0.action == action }) else { return "" }
        return Self.modifiersString(reg.binding.modifiers) + Self.keyCodeString(reg.binding.keyCode)
    }
}
