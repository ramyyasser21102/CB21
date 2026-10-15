import Foundation
import Testing
@testable import CB21Core

private func sized(_ name: String, bytes: Int, at time: TimeInterval) -> Clip {
    Clip(
        representations: [Representation(kind: .plainText, typeIdentifier: "public.utf8-plain-text", data: Data(repeating: UInt8(ascii: "x"), count: bytes) + Data(name.utf8))],
        createdAt: Date(timeIntervalSince1970: time)
    )
}

@Test func defaultLimitsAre100ClipsAnd100MB() {
    #expect(Limits.default.maxItems == 100)
    #expect(Limits.default.maxBytes == 100 * 1024 * 1024)
}

@Test func capturingBeyondTheItemLimitEvictsTheOldest() async throws {
    let store = try ClipStore.inMemory(limits: Limits(maxItems: 2, maxBytes: .max))
    let a = textClip("A", at: 1), b = textClip("B", at: 2), c = textClip("C", at: 3)
    _ = try await store.capture(a)
    _ = try await store.capture(b)
    _ = try await store.capture(c)
    #expect(try await store.list().map(\.id) == [c.id, b.id])
}

@Test func evictionIsByLastUsedNotByCreation() async throws {
    let store = try ClipStore.inMemory(limits: Limits(maxItems: 3, maxBytes: .max))
    let a = textClip("A", at: 1), b = textClip("B", at: 2), c = textClip("C", at: 3), d = textClip("D", at: 11)
    for clip in [a, b, c] { _ = try await store.capture(clip) }
    try await store.recopy(id: a.id, at: Date(timeIntervalSince1970: 10))
    _ = try await store.capture(d)
    #expect(try await store.list().map(\.id) == [d.id, a.id, c.id])
}

@Test func capturingBeyondTheStorageLimitEvictsTheOldest() async throws {
    let store = try ClipStore.inMemory(limits: Limits(maxItems: 100, maxBytes: 25))
    let a = sized("a", bytes: 9, at: 1), b = sized("b", bytes: 9, at: 2), c = sized("c", bytes: 9, at: 3)
    _ = try await store.capture(a)
    _ = try await store.capture(b)
    _ = try await store.capture(c)
    #expect(try await store.list().map(\.id) == [c.id, b.id])
}

@Test func loweringALimitTrimsImmediatelyAndReportsHowMany() async throws {
    let store = try ClipStore.inMemory()
    for i in 1...5 { _ = try await store.capture(textClip("c\(i)", at: TimeInterval(i))) }
    let lower = Limits(maxItems: 2, maxBytes: .max)
    #expect(try await store.evictionCount(for: lower) == 3)
    #expect(try await store.count() == 5)
    #expect(try await store.setLimits(lower) == 3)
    #expect(try await store.count() == 2)
}

@Test func raisingALimitEvictsNothing() async throws {
    let store = try ClipStore.inMemory(limits: Limits(maxItems: 2, maxBytes: .max))
    _ = try await store.capture(textClip("A", at: 1))
    #expect(try await store.setLimits(.default) == 0)
}

@Test func evictedImageClipsLoseTheirFiles() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let images = dir.appendingPathComponent("images")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let store = try ClipStore(path: dir.appendingPathComponent("h.sqlite").path, imagesDirectory: images, limits: Limits(maxItems: 1, maxBytes: .max))
    let one = Clip(representations: [Representation(kind: .image, typeIdentifier: "public.png", data: Data([1]))], createdAt: Date(timeIntervalSince1970: 1))
    let two = Clip(representations: [Representation(kind: .image, typeIdentifier: "public.png", data: Data([2]))], createdAt: Date(timeIntervalSince1970: 2))
    _ = try await store.capture(one)
    _ = try await store.capture(two)
    #expect(try FileManager.default.contentsOfDirectory(atPath: images.path).count == 1)
}
