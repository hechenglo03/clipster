import Foundation
import CoreGraphics
import Carbon

let source = CGEventSource(stateID: .hidSystemState)
let keyCode = CGKeyCode(kVK_ANSI_M)

let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)!
down.flags = [.maskControl, .maskCommand]

let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)!
up.flags = [.maskControl, .maskCommand]

down.post(tap: .cghidEventTap)
Thread.sleep(forTimeInterval: 0.05)
up.post(tap: .cghidEventTap)

print("sent ⌃M")
