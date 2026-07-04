import Foundation
import SQLite3

final class GroupRepository {
    private let db: Database

    init(_ db: Database) {
        self.db = db
    }

    @discardableResult
    func insert(_ group: ClipGroup) -> Int64? {
        let sql = """
        INSERT INTO groups (name, color, icon, sort_order, created_at, updated_at)
        VALUES (?,?,?,?,?,?);
        """
        guard let stmt = try? db.prepare(sql) else { return nil }
        defer { db.finalize(stmt) }

        sqlite3_bind_text(stmt, 1, group.name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, group.color, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        if let icon = group.icon {
            sqlite3_bind_text(stmt, 3, icon, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else { sqlite3_bind_null(stmt, 3) }
        sqlite3_bind_int(stmt, 4, Int32(group.sortOrder))
        sqlite3_bind_double(stmt, 5, group.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 6, group.updatedAt.timeIntervalSince1970)

        if db.step(stmt) != SQLITE_DONE { return nil }
        return db.lastInsertRowID()
    }

    func update(_ group: ClipGroup) -> Bool {
        guard let id = group.id else { return false }
        let sql = """
        UPDATE groups SET name = ?, color = ?, icon = ?, sort_order = ?, updated_at = ?
        WHERE id = ?;
        """
        guard let stmt = try? db.prepare(sql) else { return false }
        defer { db.finalize(stmt) }

        sqlite3_bind_text(stmt, 1, group.name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, group.color, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        if let icon = group.icon {
            sqlite3_bind_text(stmt, 3, icon, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else { sqlite3_bind_null(stmt, 3) }
        sqlite3_bind_int(stmt, 4, Int32(group.sortOrder))
        sqlite3_bind_double(stmt, 5, Date().timeIntervalSince1970)
        sqlite3_bind_int64(stmt, 6, id)

        return db.step(stmt) == SQLITE_DONE
    }

    func delete(id: Int64) {
        db.execute("DELETE FROM groups WHERE id = \(id);")
    }

    func fetchAll() -> [ClipGroup] {
        let sql = "SELECT * FROM groups ORDER BY sort_order ASC, created_at ASC;"
        return query(sql)
    }

    func fetch(id: Int64) -> ClipGroup? {
        let sql = "SELECT * FROM groups WHERE id = \(id) LIMIT 1;"
        return query(sql).first
    }

    func exists(name: String) -> Bool {
        let sql = "SELECT 1 FROM groups WHERE name = ? LIMIT 1;"
        guard let stmt = try? db.prepare(sql) else { return false }
        defer { db.finalize(stmt) }
        sqlite3_bind_text(stmt, 1, name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        return db.step(stmt) == SQLITE_ROW
    }

    func addItem(_ itemId: Int64, to groupId: Int64) -> Bool {
        let sql = "INSERT OR IGNORE INTO item_groups (item_id, group_id, created_at) VALUES (?, ?, ?);"
        guard let stmt = try? db.prepare(sql) else { return false }
        defer { db.finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, itemId)
        sqlite3_bind_int64(stmt, 2, groupId)
        sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
        return db.step(stmt) == SQLITE_DONE
    }

    func removeItem(_ itemId: Int64, from groupId: Int64) {
        db.execute("DELETE FROM item_groups WHERE item_id = \(itemId) AND group_id = \(groupId);")
    }

    func removeItemFromAllGroups(_ itemId: Int64) {
        db.execute("DELETE FROM item_groups WHERE item_id = \(itemId);")
    }

    func groupIds(for itemId: Int64) -> [Int64] {
        let sql = "SELECT group_id FROM item_groups WHERE item_id = \(itemId);"
        guard let stmt = try? db.prepare(sql) else { return [] }
        defer { db.finalize(stmt) }
        var result: [Int64] = []
        while db.step(stmt) == SQLITE_ROW {
            result.append(sqlite3_column_int64(stmt, 0))
        }
        return result
    }

    func itemCount(in groupId: Int64) -> Int {
        let sql = "SELECT COUNT(*) FROM item_groups WHERE group_id = \(groupId);"
        guard let stmt = try? db.prepare(sql) else { return 0 }
        defer { db.finalize(stmt) }
        if db.step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    private func query(_ sql: String) -> [ClipGroup] {
        guard let stmt = try? db.prepare(sql) else { return [] }
        defer { db.finalize(stmt) }
        var groups: [ClipGroup] = []
        while db.step(stmt) == SQLITE_ROW {
            groups.append(rowToGroup(stmt))
        }
        return groups
    }

    private func rowToGroup(_ stmt: OpaquePointer?) -> ClipGroup {
        ClipGroup(
            id: sqlite3_column_int64(stmt, 0),
            name: columnText(stmt, 1) ?? "",
            color: columnText(stmt, 2) ?? "#5b8cff",
            icon: columnText(stmt, 3),
            sortOrder: Int(sqlite3_column_int(stmt, 4)),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
        )
    }

    private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cstr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cstr)
    }
}
