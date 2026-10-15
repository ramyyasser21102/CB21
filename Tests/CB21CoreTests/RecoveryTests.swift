import Foundation
import Testing
@testable import CB21Core

private func tempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@Test func healthyDatabaseOpensWithoutRecovery() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("history.sqlite")
    let clip = textClip("keep")
    do {
        let store = try ClipStore(path: url.path)
        try await store.insert(clip)
    }
    let opened = try ClipStore.openRecovering(at: url)
    #expect(opened.recoveredFrom == nil)
    #expect(try await opened.store.list() == [clip])
}

@Test func missingDatabaseIsCreatedWithoutRecovery() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let opened = try ClipStore.openRecovering(at: dir.appendingPathComponent("history.sqlite"))
    #expect(opened.recoveredFrom == nil)
    #expect(try await opened.store.count() == 0)
}

@Test func corruptDatabaseIsMovedAsideAndReplacedByAnEmptyOne() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("history.sqlite")
    try Data("this is not a database, just garbage bytes".utf8).write(to: url)
    let opened = try ClipStore.openRecovering(at: url, now: Date(timeIntervalSince1970: 1_800_000_000))
    let moved = try #require(opened.recoveredFrom)
    #expect(moved.lastPathComponent.hasPrefix("history-corrupt-"))
    #expect(moved.pathExtension == "sqlite")
    #expect(FileManager.default.fileExists(atPath: moved.path))
    #expect(try await opened.store.count() == 0)
    try await opened.store.insert(textClip("works again"))
    #expect(try await opened.store.count() == 1)
}
