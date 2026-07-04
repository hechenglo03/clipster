import Foundation

enum Category: String, CaseIterable, Codable {
    case text
    case link
    case image
    case code
    case favorite
    case locked

    var displayName: String {
        switch self {
        case .text:     return "文本"
        case .link:     return "链接"
        case .image:    return "图片"
        case .code:     return "代码"
        case .favorite: return "常用"
        case .locked:   return "私密"
        }
    }

    var emoji: String {
        switch self {
        case .text:     return "📝"
        case .link:     return "🔗"
        case .image:    return "🖼"
        case .code:     return "⌥"
        case .favorite: return "⭐"
        case .locked:   return "🔒"
        }
    }
}
