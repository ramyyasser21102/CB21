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
