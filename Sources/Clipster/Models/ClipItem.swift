import Foundation

struct ClipItem: Identifiable, Codable, Equatable {
    var id: Int64?
    var content: String
    var contentHash: String
    var category: Category
    var mimeType: String?
    var payloadURL: String?
    var sizeBytes: Int64
    var isFavorite: Bool
    var isLocked: Bool
    var appSource: String?
    var createdAt: Date
    var pinnedAt: Date?

    init(
        id: Int64? = nil,
        content: String,
        contentHash: String,
        category: Category,
        mimeType: String? = nil,
        payloadURL: String? = nil,
        sizeBytes: Int64 = 0,
        isFavorite: Bool = false,
        isLocked: Bool = false,
        appSource: String? = nil,
        createdAt: Date = Date(),
        pinnedAt: Date? = nil
    ) {
        self.id = id
        self.content = content
        self.contentHash = contentHash
        self.category = category
        self.mimeType = mimeType
        self.payloadURL = payloadURL
        self.sizeBytes = sizeBytes
        self.isFavorite = isFavorite
        self.isLocked = isLocked
        self.appSource = appSource
        self.createdAt = createdAt
        self.pinnedAt = pinnedAt
    }

    var displayTitle: String {
        switch category {
        case .image:
            if let url = payloadURL {
                return URL(fileURLWithPath: url).lastPathComponent
            }
            return content
        default:
            return content
        }
    }

    var subtitle: String {
        switch category {
        case .text:
            return "文本 · \(content.count) 字"
        case .link:
            return "链接"
        case .image:
            return "图片 · \(formatSize(sizeBytes))"
        case .code:
            let lines = content.filter { $0 == "\n" }.count + 1
            return "代码 · \(lines) 行"
        case .favorite:
            return "收藏"
        case .locked:
            return "私密"
        }
    }

    func relativeTime(now: Date = Date()) -> String {
        let diff = now.timeIntervalSince(createdAt)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60)) 分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600)) 小时前" }
        if diff < 86400 * 2 { return "昨天" }
        let df = DateFormatter()
        df.dateFormat = "MM-dd"
        return df.string(from: createdAt)
    }

    private func formatSize(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useAll]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}
