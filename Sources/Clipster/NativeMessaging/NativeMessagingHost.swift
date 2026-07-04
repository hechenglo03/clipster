import Foundation
import SQLite3

/// Native Messaging host for Chrome extension.
/// Reads JSON messages from stdin (4-byte length prefix + JSON body)
/// and writes responses in the same format.
enum NativeMessagingHost {
    static func run() {
        let dbPath = Database.defaultPath()
        guard let db = try? Database(path: dbPath) else {
            writeError("Failed to open database")
            return
        }
        let repository = ItemRepository(db)

        while true {
            guard let message = readMessage() else { break }

            guard let action = message["action"] as? String else {
                writeResponse(["error": "missing action"])
                continue
            }

            switch action {
            case "list":
                let limit = (message["limit"] as? Int) ?? 20
                let items = repository.fetchAll(limit: limit).map { item in
                    [
                        "id": item.id ?? 0,
                        "content": item.content,
                        "title": item.displayTitle,
                        "category": item.category.rawValue,
                        "timestamp": ISO8601DateFormatter().string(from: item.createdAt)
                    ] as [String: Any]
                }
                writeResponse(["items": items])
            case "search":
                let keyword = (message["keyword"] as? String) ?? ""
                let items = repository.search(keyword: keyword, limit: 20).map { item in
                    [
                        "id": item.id ?? 0,
                        "content": item.content,
                        "title": item.displayTitle,
                        "category": item.category.rawValue,
                        "timestamp": ISO8601DateFormatter().string(from: item.createdAt)
                    ] as [String: Any]
                }
                writeResponse(["items": items])
            default:
                writeResponse(["error": "unknown action: \(action)"])
            }
        }
    }

    private static func readMessage() -> [String: Any]? {
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let readCount = lengthBytes.withUnsafeMutableBytes { ptr in
            fread(ptr.baseAddress!, 1, 4, stdin)
        }
        guard readCount == 4 else { return nil }

        let length = lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        guard length > 0 && length < 10_000_000 else { return nil }

        var jsonBytes = [UInt8](repeating: 0, count: Int(length))
        let bodyCount = jsonBytes.withUnsafeMutableBytes { ptr in
            fread(ptr.baseAddress!, 1, Int(length), stdin)
        }
        guard bodyCount == Int(length) else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: Data(jsonBytes), options: []),
              let dict = json as? [String: Any] else {
            return nil
        }
        return dict
    }

    private static func writeResponse(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else { return }
        var length = UInt32(data.count).littleEndian
        fwrite(&length, 1, 4, stdout)
        _ = data.withUnsafeBytes { ptr in
            fwrite(ptr.baseAddress!, 1, data.count, stdout)
        }
        fflush(stdout)
    }

    private static func writeError(_ message: String) {
        writeResponse(["error": message])
    }
}
