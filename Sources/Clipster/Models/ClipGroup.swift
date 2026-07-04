import Foundation
import AppKit

struct ClipGroup: Identifiable, Codable, Equatable {
    var id: Int64?
    var name: String
    var color: String
    var icon: String?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        name: String,
        color: String = "#5b8cff",
        icon: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var nsColor: NSColor {
        NSColor.fromHex(color) ?? NSColor(srgbRed: 0.36, green: 0.55, blue: 1.0, alpha: 1)
    }
}

struct GroupActionContext {
    let itemId: Int64
    let groupId: Int64
}

extension NSColor {
    static func fromHex(_ hex: String) -> NSColor? {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
