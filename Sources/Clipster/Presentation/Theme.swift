import AppKit

enum Theme {
    static let bg = NSColor(srgbRed: 0.04, green: 0.04, blue: 0.05, alpha: 1)
    static let surface = NSColor(srgbRed: 0.09, green: 0.09, blue: 0.10, alpha: 1)
    static let surface2 = NSColor(srgbRed: 0.12, green: 0.12, blue: 0.14, alpha: 1)
    static let surface3 = NSColor(srgbRed: 0.15, green: 0.15, blue: 0.17, alpha: 1)
    static let border = NSColor(white: 1, alpha: 0.08)
    static let borderStrong = NSColor(white: 1, alpha: 0.14)
    static let text = NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1)
    static let textDim = NSColor(srgbRed: 0.63, green: 0.63, blue: 0.67, alpha: 1)
    static let textFaint = NSColor(srgbRed: 0.42, green: 0.42, blue: 0.45, alpha: 1)
    static let accent = NSColor(srgbRed: 0.37, green: 0.62, blue: 1.0, alpha: 1)
    static let accent2 = NSColor(srgbRed: 0.72, green: 0.52, blue: 1.0, alpha: 1)
    static let green = NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1)
    static let orange = NSColor(srgbRed: 1.0, green: 0.62, blue: 0.04, alpha: 1)
    static let pink = NSColor(srgbRed: 1.0, green: 0.22, blue: 0.37, alpha: 1)
    static let purple = NSColor(srgbRed: 0.72, green: 0.52, blue: 1.0, alpha: 1)
    static let teal = NSColor(srgbRed: 0.37, green: 0.83, blue: 0.82, alpha: 1)

    static func tagColor(_ category: Category) -> NSColor {
        switch category {
        case .text:     return accent
        case .link:     return purple
        case .image:    return green
        case .code:     return orange
        case .favorite: return orange
        case .locked:   return pink
        }
    }
}
