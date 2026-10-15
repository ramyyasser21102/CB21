import Foundation
import Testing
@testable import CB21Core

func textClip(_ s: String, at time: TimeInterval = 0) -> Clip {
    Clip(
        representations: [Representation(kind: .plainText, typeIdentifier: "public.utf8-plain-text", data: Data(s.utf8))],
        createdAt: Date(timeIntervalSince1970: time)
    )
}

@Test func insertedClipsComeBackNewestUsedFirst() async throws {
    let store = try ClipStore.inMemory()
    let a = textClip("a", at: 1)
    let b = textClip("b", at: 2)
    try await store.insert(a)
    try await store.insert(b)
    let clips = try await store.list()
    #expect(clips.map(\.id) == [b.id, a.id])
}

@Test func listedClipKeepsItsRepresentationsAndDates() async throws {
    let store = try ClipStore.inMemory()
    let rich = Representation(kind: .richText, typeIdentifier: "public.rtf", data: Data("{rtf}".utf8))
    let plain = Representation(kind: .plainText, typeIdentifier: "public.utf8-plain-text", data: Data("hi".utf8))
    let clip = Clip(representations: [plain, rich], createdAt: Date(timeIntervalSince1970: 10), lastUsedAt: Date(timeIntervalSince1970: 20))
    try await store.insert(clip)
    let back = try await store.list()
    #expect(back == [clip])
}

@Test func countReflectsInsertedClips() async throws {
    let store = try ClipStore.inMemory()
    #expect(try await store.count() == 0)
    try await store.insert(textClip("a"))
    #expect(try await store.count() == 1)
}

@Test func historySurvivesReopeningTheDatabase() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("history.sqlite")
    let clip = textClip("persist")
    do {
        let store = try ClipStore(path: url.path)
        try await store.insert(clip)
    }
    let reopened = try ClipStore(path: url.path)
    #expect(try await reopened.list() == [clip])
}

@Test func secureDeleteIsOn() async throws {
    let store = try ClipStore.inMemory()
    #expect(try await store.secureDeleteSetting() == 1)
}

@Test func copyEqualToTheTopClipIsADuplicateAndNotStored() async throws {
    let store = try ClipStore.inMemory()
    #expect(try await store.capture(textClip("A", at: 1)) == .stored)
    #expect(try await store.capture(textClip("A", at: 2)) == .duplicate)
    #expect(try await store.count() == 1)
}

@Test func copyingABAStoresAAgainBecauseOnlyConsecutiveDuplicatesCollapse() async throws {
    let store = try ClipStore.inMemory()
    _ = try await store.capture(textClip("A", at: 1))
    _ = try await store.capture(textClip("B", at: 2))
    #expect(try await store.capture(textClip("A", at: 3)) == .stored)
    let texts = try await store.list().map { String(decoding: $0.preferred.data, as: UTF8.self) }
    #expect(texts == ["A", "B", "A"])
}

@Test func duplicateIsComparedAgainstTheMostRecentlyUsedClip() async throws {
    let store = try ClipStore.inMemory()
    _ = try await store.capture(textClip("A", at: 1))
    _ = try await store.capture(textClip("B", at: 2))
    #expect(try await store.capture(textClip("B", at: 3)) == .duplicate)
    #expect(try await store.count() == 2)
}

@Test func recopyMovesTheClipToTheTopWithoutAddingOne() async throws {
    let store = try ClipStore.inMemory()
    let a = textClip("A", at: 1)
    let b = textClip("B", at: 2)
    _ = try await store.capture(a)
    _ = try await store.capture(b)
    try await store.recopy(id: a.id, at: Date(timeIntervalSince1970: 5))
    let clips = try await store.list()
    #expect(clips.map(\.id) == [a.id, b.id])
    #expect(clips.first?.lastUsedAt == Date(timeIntervalSince1970: 5))
    #expect(clips.first?.createdAt == Date(timeIntervalSince1970: 1))
}

@Test func recopiedClipBecomesTheDuplicateReference() async throws {
    let store = try ClipStore.inMemory()
    let a = textClip("A", at: 1)
    _ = try await store.capture(a)
    _ = try await store.capture(textClip("B", at: 2))
    try await store.recopy(id: a.id, at: Date(timeIntervalSince1970: 5))
    #expect(try await store.capture(textClip("A", at: 6)) == .duplicate)
}

@Test func recopyOfAnUnknownClipThrows() async throws {
    let store = try ClipStore.inMemory()
    await #expect(throws: StoreError.self) {
        try await store.recopy(id: UUID(), at: Date())
    }
}

private func imageClip(_ bytes: [UInt8], at time: TimeInterval = 0) -> Clip {
    Clip(
        representations: [Representation(kind: .image, typeIdentifier: "public.png", data: Data(bytes))],
        createdAt: Date(timeIntervalSince1970: time)
    )
}

private func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@Test func imageBytesAreStoredAsFilesNotInTheDatabase() async throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let images = dir.appendingPathComponent("images")
    let store = try ClipStore(path: dir.appendingPathComponent("h.sqlite").path, imagesDirectory: images)
    let clip = imageClip([1, 2, 3, 4])
    try await store.insert(clip)
    let files = try FileManager.default.contentsOfDirectory(atPath: images.path)
    #expect(files.count == 1)
    #expect(try await store.list() == [clip])
}

@Test func nonImageRepresentationsStayInTheDatabase() async throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let images = dir.appendingPathComponent("images")
    let store = try ClipStore(path: dir.appendingPathComponent("h.sqlite").path, imagesDirectory: images)
    try await store.insert(textClip("just text"))
    let files = (try? FileManager.default.contentsOfDirectory(atPath: images.path)) ?? []
    #expect(files.isEmpty)
}

@Test func imageClipsSurviveReopening() async throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let images = dir.appendingPathComponent("images")
    let path = dir.appendingPathComponent("h.sqlite").path
    let clip = imageClip([9, 8, 7])
    do {
        let store = try ClipStore(path: path, imagesDirectory: images)
        try await store.insert(clip)
    }
    let reopened = try ClipStore(path: path, imagesDirectory: images)
    #expect(try await reopened.list() == [clip])
}

@Test func clipWhoseImageFileIsMissingIsLeftOutOfTheList() async throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let images = dir.appendingPathComponent("images")
    let store = try ClipStore(path: dir.appendingPathComponent("h.sqlite").path, imagesDirectory: images)
    try await store.insert(imageClip([1], at: 1))
    try await store.insert(textClip("ok", at: 2))
    for name in try FileManager.default.contentsOfDirectory(atPath: images.path) {
        try FileManager.default.removeItem(at: images.appendingPathComponent(name))
    }
    let clips = try await store.list()
    #expect(clips.count == 1)
}
