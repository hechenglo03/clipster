import Foundation
import SQLite3

final class Database {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.clipster.db")

    let path: String

    init(path: String) throws {
        self.path = path
        var handle: OpaquePointer?
        if sqlite3_open(path, &handle) != SQLITE_OK {
            throw DatabaseError.openFailed(message(handle))
        }
        db = handle
        execute("PRAGMA journal_mode = WAL;")
        execute("PRAGMA foreign_keys = ON;")
        try createSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    static func defaultPath() -> String {
        let fm = FileManager.default
        let appSupport = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("Clipster")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipster.sqlite").path
    }

    func execute(_ sql: String) {
        queue.sync {
            _ = sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw DatabaseError.prepareFailed(message(db))
        }
        return stmt
    }

    func step(_ stmt: OpaquePointer?) -> Int32 {
        sqlite3_step(stmt)
    }

    func finalize(_ stmt: OpaquePointer?) {
        sqlite3_finalize(stmt)
    }

    func lastInsertRowID() -> Int64 {
        sqlite3_last_insert_rowid(db)
    }

    func errorMessage() -> String {
        message(db)
    }

    private func message(_ handle: OpaquePointer?) -> String {
        if let m = sqlite3_errmsg(handle) {
            return String(cString: m)
        }
        return "unknown"
    }

    private func createSchema() throws {
        let schema = """
        CREATE TABLE IF NOT EXISTS clip_item (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            content      TEXT NOT NULL,
            content_hash TEXT UNIQUE NOT NULL,
            category     TEXT NOT NULL,
            mime_type    TEXT,
            payload_url  TEXT,
            size_bytes   INTEGER DEFAULT 0,
            is_favorite  INTEGER DEFAULT 0,
            is_locked    INTEGER DEFAULT 0,
            app_source   TEXT,
            created_at   REAL NOT NULL,
            pinned_at    REAL
        );
        CREATE INDEX IF NOT EXISTS idx_cat  ON clip_item(category);
        CREATE INDEX IF NOT EXISTS idx_time ON clip_item(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_fav  ON clip_item(is_favorite) WHERE is_favorite = 1;

        CREATE VIRTUAL TABLE IF NOT EXISTS clip_fts USING fts5(
            content, category, tokenize = 'unicode61'
        );

        CREATE TABLE IF NOT EXISTS groups (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL UNIQUE,
            color       TEXT NOT NULL DEFAULT '#5b8cff',
            icon        TEXT,
            sort_order  INTEGER DEFAULT 0,
            created_at  REAL NOT NULL,
            updated_at  REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS item_groups (
            item_id     INTEGER NOT NULL,
            group_id    INTEGER NOT NULL,
            created_at  REAL NOT NULL,
            PRIMARY KEY (item_id, group_id),
            FOREIGN KEY (item_id) REFERENCES clip_item(id) ON DELETE CASCADE,
            FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_ig_group ON item_groups(group_id);
        CREATE INDEX IF NOT EXISTS idx_ig_item  ON item_groups(item_id);

        CREATE TRIGGER IF NOT EXISTS ai_item AFTER INSERT ON clip_item BEGIN
            INSERT INTO clip_fts(rowid, content, category)
            VALUES (new.id, new.content, new.category);
        END;
        CREATE TRIGGER IF NOT EXISTS ad_item AFTER DELETE ON clip_item BEGIN
            DELETE FROM clip_fts WHERE rowid = old.id;
        END;
        CREATE TRIGGER IF NOT EXISTS au_item AFTER UPDATE ON clip_item BEGIN
            DELETE FROM clip_fts WHERE rowid = old.id;
            INSERT INTO clip_fts(rowid, content, category)
            VALUES (new.id, new.content, new.category);
        END;
        """
        if sqlite3_exec(db, schema, nil, nil, nil) != SQLITE_OK {
            throw DatabaseError.schemaFailed(errorMessage())
        }
    }
}

enum DatabaseError: Error {
    case openFailed(String)
    case prepareFailed(String)
    case schemaFailed(String)
    case stepFailed(String)
    case bindFailed(String)
}
