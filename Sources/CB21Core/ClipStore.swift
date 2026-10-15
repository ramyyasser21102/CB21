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

    private let imagesDirectory: URL?
    private var limits: Limits

    /// - Parameter imagesDirectory: where image bytes are kept as files. When nil, they stay in the database.
    public init(path: String, imagesDirectory: URL? = nil, limits: Limits = .default) throws {
        self.imagesDirectory = imagesDirectory
        self.limits = limits
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
                    file_name TEXT,
                    PRIMARY KEY (clip_id, position)
                )
                """)
        } catch {
            sqlite3_close(handle)
            throw error
        }
    }

    public static func inMemory(limits: Limits = .default) throws -> ClipStore {
        try ClipStore(path: ":memory:", limits: limits)
    }

    /// Opens the database at `url`. If it is corrupt, moves it aside under a timestamped name and
    /// starts a new empty one. `recoveredFrom` is the moved file's location when that happened.
    public static func openRecovering(
        at url: URL,
        imagesDirectory: URL? = nil,
        limits: Limits = .default,
        now: Date = Date()
    ) throws -> (store: ClipStore, recoveredFrom: URL?) {
        if FileManager.default.fileExists(atPath: url.path) {
            if let store = try? ClipStore(path: url.path, imagesDirectory: imagesDirectory, limits: limits),
               store.isIntact() {
                return (store, nil)
            }
            let stamp = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "-")
            let base = url.deletingPathExtension().lastPathComponent
            let moved = url.deletingLastPathComponent()
                .appendingPathComponent("\(base)-corrupt-\(stamp).\(url.pathExtension)")
            try FileManager.default.moveItem(at: url, to: moved)
            for suffix in ["-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: url.path + suffix)
            }
            let store = try ClipStore(path: url.path, imagesDirectory: imagesDirectory, limits: limits)
            return (store, moved)
        }
        return (try ClipStore(path: url.path, imagesDirectory: imagesDirectory, limits: limits), nil)
    }

    /// Runs SQLite's quick integrity check. Safe to call from outside the actor only during opening.
    nonisolated func isIntact() -> Bool {
        guard let db else { return false }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA quick_check", -1, &stmt, nil) == SQLITE_OK, let stmt else { return false }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) else { return false }
        return String(cString: text) == "ok"
    }

    deinit {
        sqlite3_close(db)
    }

    public func insert(_ clip: Clip) throws {
        let db = try handle()
        var writtenFiles: [URL] = []
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
                var fileName: String?
                if rep.kind == .image, let imagesDirectory {
                    try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
                    let name = "\(clip.id.uuidString)-\(position)"
                    let url = imagesDirectory.appendingPathComponent(name)
                    try rep.data.write(to: url, options: .atomic)
                    writtenFiles.append(url)
                    fileName = name
                }
                try run(db, "INSERT INTO representations VALUES (?, ?, ?, ?, ?, ?)") { stmt in
                    sqlite3_bind_text(stmt, 1, clip.id.uuidString, -1, sqliteTransient)
                    sqlite3_bind_int(stmt, 2, Int32(position))
                    sqlite3_bind_text(stmt, 3, rep.kind.rawValue, -1, sqliteTransient)
                    sqlite3_bind_text(stmt, 4, rep.typeIdentifier, -1, sqliteTransient)
                    let inline = fileName == nil ? rep.data : Data()
                    _ = inline.withUnsafeBytes { bytes in
                        sqlite3_bind_blob(stmt, 5, bytes.baseAddress, Int32(bytes.count), sqliteTransient)
                    }
                    if let fileName {
                        sqlite3_bind_text(stmt, 6, fileName, -1, sqliteTransient)
                    } else {
                        sqlite3_bind_null(stmt, 6)
                    }
                }
            }
            try Self.execute(db, "COMMIT")
        } catch {
            try? Self.execute(db, "ROLLBACK")
            for url in writtenFiles { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }

    /// Permanently deletes Clips, including their image files. Unknown ids are ignored.
    public func delete(ids: [UUID]) throws {
        let db = try handle()
        try Self.execute(db, "BEGIN")
        var files: [String] = []
        do {
            for id in ids {
                try query(db, "SELECT file_name FROM representations WHERE clip_id = ? AND file_name IS NOT NULL",
                          bind: { sqlite3_bind_text($0, 1, id.uuidString, -1, sqliteTransient) }) {
                    files.append(String(cString: sqlite3_column_text($0, 0)))
                }
                try run(db, "DELETE FROM clips WHERE id = ?") { sqlite3_bind_text($0, 1, id.uuidString, -1, sqliteTransient) }
            }
            try Self.execute(db, "COMMIT")
        } catch {
            try? Self.execute(db, "ROLLBACK")
            throw error
        }
        removeImageFiles(files)
    }

    /// Permanently deletes every Clip (Clear all).
    public func deleteAll() throws {
        let db = try handle()
        var files: [String] = []
        try query(db, "SELECT file_name FROM representations WHERE file_name IS NOT NULL") {
            files.append(String(cString: sqlite3_column_text($0, 0)))
        }
        try Self.execute(db, "DELETE FROM clips")
        removeImageFiles(files)
    }

    /// Removes image files that no row refers to, left behind by an interrupted delete. Returns how many.
    public func sweepOrphanedImageFiles() throws -> Int {
        guard let imagesDirectory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path) else { return 0 }
        var known = Set<String>()
        try query(try handle(), "SELECT file_name FROM representations WHERE file_name IS NOT NULL") {
            known.insert(String(cString: sqlite3_column_text($0, 0)))
        }
        let orphans = names.filter { !known.contains($0) }
        removeImageFiles(orphans)
        return orphans.count
    }

    private func removeImageFiles(_ names: [String]) {
        guard let imagesDirectory else { return }
        for name in names {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(name))
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
        return try rows.compactMap { row -> Clip? in
            var missingFile = false
            var reps: [Representation] = []
            try query(db, "SELECT kind, type_identifier, data, file_name FROM representations WHERE clip_id = ? ORDER BY position",
                      bind: { sqlite3_bind_text($0, 1, row.id.uuidString, -1, sqliteTransient) }) { stmt in
                var data: Data
                if let file = sqlite3_column_text(stmt, 3), let imagesDirectory {
                    let url = imagesDirectory.appendingPathComponent(String(cString: file))
                    guard let contents = try? Data(contentsOf: url) else {
                        missingFile = true
                        return
                    }
                    data = contents
                } else {
                    let count = Int(sqlite3_column_bytes(stmt, 2))
                    data = count == 0 ? Data() : Data(bytes: sqlite3_column_blob(stmt, 2), count: count)
                }
                reps.append(Representation(
                    kind: Representation.Kind(rawValue: String(cString: sqlite3_column_text(stmt, 0)))!,
                    typeIdentifier: String(cString: sqlite3_column_text(stmt, 1)),
                    data: data
                ))
            }
            if missingFile || reps.isEmpty { return nil }
            return Clip(id: row.id, representations: reps, createdAt: row.created, lastUsedAt: row.used)
        }
    }

    public func clip(id: UUID) throws -> Clip? {
        try list().first { $0.id == id }
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

/// The two user-set caps on History.
public struct Limits: Sendable, Equatable {
    public var maxItems: Int
    public var maxBytes: Int

    public init(maxItems: Int, maxBytes: Int) {
        self.maxItems = maxItems
        self.maxBytes = maxBytes
    }

    public static let `default` = Limits(maxItems: 100, maxBytes: 100 * 1024 * 1024)
}

public enum CaptureResult: Sendable, Equatable {
    case stored
    case duplicate
    /// Larger than the whole storage Limit. Nothing is stored or evicted.
    case rejectedTooLarge
}

extension ClipStore {
    func usageNewestFirst() throws -> [(id: UUID, bytes: Int)] {
        var rows: [(id: UUID, bytes: Int)] = []
        try query(try handle(), "SELECT id, byte_count FROM clips ORDER BY last_used_at DESC, created_at DESC") {
            rows.append((UUID(uuidString: String(cString: sqlite3_column_text($0, 0)))!, Int(sqlite3_column_int64($0, 1))))
        }
        return rows
    }

    /// Records a new copy. A copy equal to the Clip at the top of History is a Duplicate and is not stored.
    public func capture(_ clip: Clip) throws -> CaptureResult {
        if clip.byteCount > limits.maxBytes {
            return .rejectedTooLarge
        }
        if try topContentKey() == clip.contentKey {
            return .duplicate
        }
        try insert(clip)
        _ = try evict(to: limits)
        return .stored
    }

    /// Applies new Limits and trims History immediately. Returns how many Clips were evicted.
    public func setLimits(_ newLimits: Limits) throws -> Int {
        limits = newLimits
        return try evict(to: newLimits)
    }

    /// How many Clips would be evicted if these Limits were applied now (for the trim warning).
    public func evictionCount(for candidate: Limits) throws -> Int {
        try evictionVictims(for: candidate).count
    }

    private func evict(to target: Limits) throws -> Int {
        let victims = try evictionVictims(for: target)
        try delete(ids: victims)
        return victims.count
    }

    private func evictionVictims(for target: Limits) throws -> [UUID] {
        var items = 0
        var bytes = 0
        var victims: [UUID] = []
        for entry in try usageNewestFirst() {
            items += 1
            bytes += entry.bytes
            if items > target.maxItems || bytes > target.maxBytes {
                victims.append(entry.id)
            }
        }
        return victims
    }
}
