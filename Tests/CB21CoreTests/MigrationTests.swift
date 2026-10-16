import Foundation
import SQLite3
import Testing
@testable import CB21Core

/// Creates a database the way the first released version did: no `user_version`, no `source_app_name`.
private func makeOldDatabase(at path: String, clipID: UUID) throws {
    var db: OpaquePointer?
    #expect(sqlite3_open(path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    let sql = """
        CREATE TABLE clips (
            id TEXT PRIMARY KEY, content_key TEXT NOT NULL, created_at REAL NOT NULL,
            last_used_at REAL NOT NULL, byte_count INTEGER NOT NULL);
        CREATE TABLE representations (
            clip_id TEXT NOT NULL REFERENCES clips(id) ON DELETE CASCADE, position INTEGER NOT NULL,
            kind TEXT NOT NULL, type_identifier TEXT NOT NULL, data BLOB NOT NULL, file_name TEXT,
            PRIMARY KEY (clip_id, position));
        INSERT INTO clips VALUES ('\(clipID.uuidString)', 'key', 10, 20, 3);
        INSERT INTO representations VALUES ('\(clipID.uuidString)', 0, 'plainText', 'public.utf8-plain-text', X'616263', NULL);
        """
    #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
}

private func tempPath() throws -> (dir: URL, path: String) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return (dir, dir.appendingPathComponent("history.sqlite").path)
}

@Test func freshDatabaseIsAtTheLatestSchemaVersion() async throws {
    let store = try ClipStore.inMemory()
    #expect(try await store.schemaVersion() == ClipStore.latestSchemaVersion)
    #expect(try await store.hasColumn("source_app_name", in: "clips"))
}

@Test func oldDatabaseIsMigratedAndKeepsItsClips() async throws {
    let (dir, path) = try tempPath()
    defer { try? FileManager.default.removeItem(at: dir) }
    let id = UUID()
    try makeOldDatabase(at: path, clipID: id)
    let store = try ClipStore(path: path)
    #expect(try await store.schemaVersion() == ClipStore.latestSchemaVersion)
    #expect(try await store.hasColumn("source_app_name", in: "clips"))
    let clips = try await store.list()
    #expect(clips.map(\.id) == [id])
    #expect(clips.first?.preferred.data == Data("abc".utf8))
}

@Test func migratingTwiceChangesNothing() async throws {
    let (dir, path) = try tempPath()
    defer { try? FileManager.default.removeItem(at: dir) }
    try makeOldDatabase(at: path, clipID: UUID())
    do { _ = try ClipStore(path: path) }
    let again = try ClipStore(path: path)
    #expect(try await again.schemaVersion() == ClipStore.latestSchemaVersion)
    #expect(try await again.count() == 1)
}

@Test func databaseFromANewerVersionIsRefusedNotTreatedAsCorrupt() async throws {
    let (dir, path) = try tempPath()
    defer { try? FileManager.default.removeItem(at: dir) }
    do {
        let store = try ClipStore(path: path)
        try await store.setSchemaVersionForTesting(ClipStore.latestSchemaVersion + 1)
    }
    #expect(throws: StoreError.newerDatabase) { _ = try ClipStore(path: path) }
    // Recovery must not move a healthy newer database aside.
    #expect(throws: StoreError.newerDatabase) { _ = try ClipStore.openRecovering(at: URL(fileURLWithPath: path)) }
    #expect(FileManager.default.fileExists(atPath: path))
}

// MARK: Migrations 2 and 3 (pinned_at, search_text)

/// A database exactly as version 1.0 left it: `user_version` 1, with `source_app_name`.
private func makeVersion1Database(at path: String, clipID: UUID) throws {
    try makeOldDatabase(at: path, clipID: clipID)
    var db: OpaquePointer?
    #expect(sqlite3_open(path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    #expect(sqlite3_exec(db, "ALTER TABLE clips ADD COLUMN source_app_name TEXT; UPDATE clips SET source_app_name = 'Notes'; PRAGMA user_version = 1;", nil, nil, nil) == SQLITE_OK)
}

@Test func freshDatabaseHasThePinAndSearchColumns() async throws {
    let store = try ClipStore.inMemory()
    #expect(try await store.hasColumn("pinned_at", in: "clips"))
    #expect(try await store.hasColumn("search_text", in: "clips"))
    #expect(ClipStore.latestSchemaVersion >= 3)
}

@Test func version1DatabaseGainsTheNewColumnsAndKeepsEverything() async throws {
    let (dir, path) = try tempPath()
    defer { try? FileManager.default.removeItem(at: dir) }
    let id = UUID()
    try makeVersion1Database(at: path, clipID: id)
    let store = try ClipStore(path: path)
    #expect(try await store.schemaVersion() == ClipStore.latestSchemaVersion)
    #expect(try await store.hasColumn("pinned_at", in: "clips"))
    #expect(try await store.hasColumn("search_text", in: "clips"))
    let clips = try await store.list()
    #expect(clips.map(\.id) == [id])
    #expect(clips.first?.sourceAppName == "Notes")
    #expect(clips.first?.preferred.data == Data("abc".utf8))
}

@Test func versionZeroDatabaseGoesStraightToTheLatestVersion() async throws {
    let (dir, path) = try tempPath()
    defer { try? FileManager.default.removeItem(at: dir) }
    try makeOldDatabase(at: path, clipID: UUID())
    let store = try ClipStore(path: path)
    #expect(try await store.schemaVersion() == ClipStore.latestSchemaVersion)
    #expect(try await store.hasColumn("pinned_at", in: "clips"))
    #expect(try await store.hasColumn("search_text", in: "clips"))
}
