import Foundation
import SQLite3

public struct StoreError: Error, CustomStringConvertible {
    public let message: String
    public var description: String { message }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQLite-backed History. Rows are overwritten on delete (`secure_delete`).
public actor ClipStore {
    // Only touched on the actor, and in deinit when no other reference exists.
    nonisolated(unsafe) private var db: OpaquePointer?

    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open(path, &handle) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open database"
            sqlite3_close(handle)
            throw StoreError(message: message)
        }
        db = handle
        do {
            try Self.execute(handle, "PRAGMA secure_delete = ON")
            try Self.execute(handle, "PRAGMA foreign_keys = ON")
            try Self.execute(handle, """
                CREATE TABLE IF NOT EXISTS clips (
                    id TEXT PRIMARY KEY,
                    content_key TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    last_used_at REAL NOT NULL,
                    byte_count INTEGER NOT NULL
                )
                """)
            try Self.execute(handle, """
                CREATE TABLE IF NOT EXISTS representations (
                    clip_id TEXT NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
                    position INTEGER NOT NULL,
                    kind TEXT NOT NULL,
                    type_identifier TEXT NOT NULL,
                    data BLOB NOT NULL,
                    PRIMARY KEY (clip_id, position)
                )
                """)
        } catch {
            sqlite3_close(handle)
            throw error
        }
    }

    public static func inMemory() throws -> ClipStore {
        try ClipStore(path: ":memory:")
    }

    deinit {
        sqlite3_close(db)
    }

    public func insert(_ clip: Clip) throws {
        let db = try handle()
        try Self.execute(db, "BEGIN")
        do {
            try run(db, "INSERT INTO clips VALUES (?, ?, ?, ?, ?)") { stmt in
                sqlite3_bind_text(stmt, 1, clip.id.uuidString, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 2, clip.contentKey, -1, sqliteTransient)
                sqlite3_bind_double(stmt, 3, clip.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 4, clip.lastUsedAt.timeIntervalSince1970)
                sqlite3_bind_int64(stmt, 5, Int64(clip.byteCount))
            }
            for (position, rep) in clip.representations.enumerated() {
                try run(db, "INSERT INTO representations VALUES (?, ?, ?, ?, ?)") { stmt in
                    sqlite3_bind_text(stmt, 1, clip.id.uuidString, -1, sqliteTransient)
                    sqlite3_bind_int(stmt, 2, Int32(position))
                    sqlite3_bind_text(stmt, 3, rep.kind.rawValue, -1, sqliteTransient)
                    sqlite3_bind_text(stmt, 4, rep.typeIdentifier, -1, sqliteTransient)
                    _ = rep.data.withUnsafeBytes { bytes in
                        sqlite3_bind_blob(stmt, 5, bytes.baseAddress, Int32(bytes.count), sqliteTransient)
                    }
                }
            }
            try Self.execute(db, "COMMIT")
        } catch {
            try? Self.execute(db, "ROLLBACK")
            throw error
        }
    }

    /// Moves an existing Clip to the top of History. It is not captured again.
    public func recopy(id: UUID, at date: Date = Date()) throws {
        let db = try handle()
        try run(db, "UPDATE clips SET last_used_at = ? WHERE id = ?") { stmt in
            sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
            sqlite3_bind_text(stmt, 2, id.uuidString, -1, sqliteTransient)
        }
        guard sqlite3_changes(db) == 1 else {
            throw StoreError(message: "no Clip with id \(id)")
        }
    }

    /// All Clips, most recently used first.
    public func list() throws -> [Clip] {
        let db = try handle()
        var rows: [(id: UUID, created: Date, used: Date)] = []
        try query(db, "SELECT id, created_at, last_used_at FROM clips ORDER BY last_used_at DESC, created_at DESC") { stmt in
            let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0)))!
            rows.append((
                id,
                Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
            ))
        }
        return try rows.map { row in
            var reps: [Representation] = []
            try query(db, "SELECT kind, type_identifier, data FROM representations WHERE clip_id = ? ORDER BY position",
                      bind: { sqlite3_bind_text($0, 1, row.id.uuidString, -1, sqliteTransient) }) { stmt in
                let count = Int(sqlite3_column_bytes(stmt, 2))
                let data = count == 0 ? Data() : Data(bytes: sqlite3_column_blob(stmt, 2), count: count)
                reps.append(Representation(
                    kind: Representation.Kind(rawValue: String(cString: sqlite3_column_text(stmt, 0)))!,
                    typeIdentifier: String(cString: sqlite3_column_text(stmt, 1)),
                    data: data
                ))
            }
            return Clip(id: row.id, representations: reps, createdAt: row.created, lastUsedAt: row.used)
        }
    }

    public func count() throws -> Int {
        var n = 0
        try query(try handle(), "SELECT COUNT(*) FROM clips") { n = Int(sqlite3_column_int64($0, 0)) }
        return n
    }

    func topContentKey() throws -> String? {
        var key: String?
        try query(try handle(), "SELECT content_key FROM clips ORDER BY last_used_at DESC, created_at DESC LIMIT 1") {
            key = String(cString: sqlite3_column_text($0, 0))
        }
        return key
    }

    func secureDeleteSetting() throws -> Int {
        var n = -1
        try query(try handle(), "PRAGMA secure_delete") { n = Int(sqlite3_column_int($0, 0)) }
        return n
    }

    // MARK: - SQLite helpers

    private func handle() throws -> OpaquePointer {
        guard let db else { throw StoreError(message: "database is closed") }
        return db
    }

    private static func execute(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw StoreError(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    private func run(_ db: OpaquePointer, _ sql: String, bind: (OpaquePointer) -> Void) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StoreError(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StoreError(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query(
        _ db: OpaquePointer,
        _ sql: String,
        bind: (OpaquePointer) -> Void = { _ in },
        row: (OpaquePointer) -> Void
    ) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw StoreError(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        while true {
            switch sqlite3_step(stmt) {
            case SQLITE_ROW: row(stmt)
            case SQLITE_DONE: return
            default: throw StoreError(message: String(cString: sqlite3_errmsg(db)))
            }
        }
    }
}

public enum CaptureResult: Sendable, Equatable {
    case stored
    case duplicate
}

extension ClipStore {
    /// Records a new copy. A copy equal to the Clip at the top of History is a Duplicate and is not stored.
    public func capture(_ clip: Clip) throws -> CaptureResult {
        if try topContentKey() == clip.contentKey {
            return .duplicate
        }
        try insert(clip)
        return .stored
    }
}
