import Foundation
import AppKit
import Carbon

final class PasteSimulator {
    private let pasteboard = NSPasteboard.general

    func paste(_ item: ClipItem, to targetApp: NSRunningApplication? = nil) {
        NSLog("[Clipster] PasteSimulator paste category=%@ content=%@", String(describing: item.category), item.content)
        switch item.category {
        case .image:
            if let path = item.payloadURL, let img = NSImage(contentsOfFile: path) {
                pasteboard.clearContents()
                pasteboard.writeObjects([img])
            }
        default:
            pasteboard.clearContents()
            pasteboard.setString(item.content, forType: .string)
        }
        NSLog("[Clipster] Pasteboard set, invoking Cmd+V")
        simulateCmdV(targetApp: targetApp)
    }

    func pasteText(_ text: String, to targetApp: NSRunningApplication? = nil) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        simulateCmdV(targetApp: targetApp)
    }

    private func simulateCmdV(targetApp: NSRunningApplication?) {
        // 先把焦点切回目标应用，否则 ⌘V 会发给 Clipster 自己
        if let app = targetApp, app != NSRunningApplication.current {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
            let vKey = UInt16(kVK_ANSI_V)

            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
            cmdDown?.flags = CGEventFlags.maskCommand
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
            cmdUp?.flags = CGEventFlags.maskCommand

            cmdDown?.post(tap: CGEventTapLocation.cgSessionEventTap)
            cmdUp?.post(tap: CGEventTapLocation.cgSessionEventTap)
        }
    }
}
