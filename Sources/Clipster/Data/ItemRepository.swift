import Foundation
import SQLite3

final class ItemRepository {
    private let db: Database

    init(_ db: Database) {
        self.db = db
    }

    @discardableResult
    func insert(_ item: ClipItem) -> Int64? {
        let sql = """
        INSERT INTO clip_item (content, content_hash, category, mime_type, payload_url,
                               size_bytes, is_favorite, is_locked, app_source, created_at, pinned_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?);
        """
        guard let stmt = try? db.prepare(sql) else { return nil }
        defer { db.finalize(stmt) }

        sqlite3_bind_text(stmt, 1, item.content, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, item.contentHash, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 3, item.category.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        if let m = item.mimeType {
            sqlite3_bind_text(stmt, 4, m, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else { sqlite3_bind_null(stmt, 4) }
        if let p = item.payloadURL {
            sqlite3_bind_text(stmt, 5, p, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else { sqlite3_bind_null(stmt, 5) }
        sqlite3_bind_int64(stmt, 6, item.sizeBytes)
        sqlite3_bind_int(stmt, 7, item.isFavorite ? 1 : 0)
        sqlite3_bind_int(stmt, 8, item.isLocked ? 1 : 0)
        if let a = item.appSource {
            sqlite3_bind_text(stmt, 9, a, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else { sqlite3_bind_null(stmt, 9) }
        sqlite3_bind_double(stmt, 10, item.createdAt.timeIntervalSince1970)
        if let pt = item.pinnedAt {
            sqlite3_bind_double(stmt, 11, pt.timeIntervalSince1970)
        } else { sqlite3_bind_null(stmt, 11) }

        if db.step(stmt) != SQLITE_DONE { return nil }
        return db.lastInsertRowID()
    }

    func exists(hash: String) -> Bool {
        let sql = "SELECT 1 FROM clip_item WHERE content_hash = ? LIMIT 1;"
        guard let stmt = try? db.prepare(sql) else { return false }
        defer { db.finalize(stmt) }
        sqlite3_bind_text(stmt, 1, hash, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        return db.step(stmt) == SQLITE_ROW
    }

    func fetchAll(category: Category? = nil, groupId: Int64? = nil, limit: Int = 200, offset: Int = 0) -> [ClipItem] {
        var conditions: [String] = []
        if let cat = category {
            if cat == .favorite {
                conditions.append("is_favorite = 1")
            } else {
                conditions.append("category = '\(cat.rawValue)'")
            }
        }
        var joins = ""
        if let gid = groupId {
            joins += " JOIN item_groups ig ON ig.item_id = clip_item.id AND ig.group_id = \(gid)"
        }
        var sql = "SELECT clip_item.* FROM clip_item\(joins)"
        if !conditions.isEmpty {
            sql += " WHERE \(conditions.joined(separator: " AND "))"
        }
        sql += " ORDER BY pinned_at DESC NULLS LAST, created_at DESC LIMIT \(limit) OFFSET \(offset);"
        return query(sql)
    }

    func search(keyword: String, category: Category? = nil, groupId: Int64? = nil, limit: Int = 50) -> [ClipItem] {
        let escaped = keyword.replacingOccurrences(of: "\"", with: "\"\"")
        var sql = """
        SELECT c.* FROM clip_fts f
        JOIN clip_item c ON c.id = f.rowid
        """
        if let gid = groupId {
            sql += " JOIN item_groups ig ON ig.item_id = c.id AND ig.group_id = \(gid)"
        }
        sql += " WHERE clip_fts MATCH \"\(escaped)*\""
        if let cat = category, cat != .favorite {
            sql += " AND c.category = '\(cat.rawValue)'"
        } else if category == .favorite {
            sql += " AND c.is_favorite = 1"
        }
        sql += " ORDER BY c.created_at DESC LIMIT \(limit);"
        return query(sql)
    }

    func delete(id: Int64) {
        db.execute("DELETE FROM item_groups WHERE item_id = \(id);")
        db.execute("DELETE FROM clip_item WHERE id = \(id);")
    }

    func toggleFavorite(id: Int64) {
        db.execute("UPDATE clip_item SET is_favorite = 1 - is_favorite, pinned_at = CASE WHEN is_favorite = 0 THEN \(Date().timeIntervalSince1970) ELSE NULL END WHERE id = \(id);")
    }

    func setPinned(id: Int64, pinned: Bool) {
        let ts = pinned ? "\(Date().timeIntervalSince1970)" : "NULL"
        db.execute("UPDATE clip_item SET is_favorite = \(pinned ? 1 : 0), pinned_at = \(ts) WHERE id = \(id);")
    }

    func clearAll(olderThan days: Int = 30, keepCount: Int = 1000) {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970
        db.execute("DELETE FROM clip_item WHERE is_favorite = 0 AND created_at < \(cutoff) AND id NOT IN (SELECT id FROM clip_item ORDER BY created_at DESC LIMIT \(keepCount));")
    }

    /// 自动清理：只保留最近 N 天的非收藏记录
    func cleanup(retentionDays days: Int) {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970
        db.execute("DELETE FROM clip_item WHERE is_favorite = 0 AND created_at < \(cutoff);")
    }

    func count() -> Int {
        guard let stmt = try? db.prepare("SELECT COUNT(*) FROM clip_item;") else { return 0 }
        defer { db.finalize(stmt) }
        if db.step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    func countByCategory() -> [Category: Int] {
        guard let stmt = try? db.prepare("SELECT category, COUNT(*) FROM clip_item GROUP BY category;") else { return [:] }
        defer { db.finalize(stmt) }
        var result: [Category: Int] = [:]
        while db.step(stmt) == SQLITE_ROW {
            if let raw = columnText(stmt, 0), let cat = Category(rawValue: raw) {
                result[cat] = Int(sqlite3_column_int(stmt, 1))
            }
        }
        if let f = fetchFavoriteCount() { result[.favorite] = f }
        return result
    }

    private func fetchFavoriteCount() -> Int? {
        guard let stmt = try? db.prepare("SELECT COUNT(*) FROM clip_item WHERE is_favorite = 1;") else { return nil }
        defer { db.finalize(stmt) }
        if db.step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return nil
    }

    private func query(_ sql: String) -> [ClipItem] {
        guard let stmt = try? db.prepare(sql) else { return [] }
        defer { db.finalize(stmt) }
        var items: [ClipItem] = []
        while db.step(stmt) == SQLITE_ROW {
            items.append(rowToItem(stmt))
        }
        return items
    }

    private func rowToItem(_ stmt: OpaquePointer?) -> ClipItem {
        ClipItem(
            id: sqlite3_column_int64(stmt, 0),
            content: columnText(stmt, 1) ?? "",
            contentHash: columnText(stmt, 2) ?? "",
            category: Category(rawValue: columnText(stmt, 3) ?? "text") ?? .text,
            mimeType: columnText(stmt, 4),
            payloadURL: columnText(stmt, 5),
            sizeBytes: sqlite3_column_int64(stmt, 6),
            isFavorite: sqlite3_column_int(stmt, 7) == 1,
            isLocked: sqlite3_column_int(stmt, 8) == 1,
            appSource: columnText(stmt, 9),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 10)),
            pinnedAt: sqlite3_column_type(stmt, 11) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 11))
        )
    }

    private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cstr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cstr)
    }
}
