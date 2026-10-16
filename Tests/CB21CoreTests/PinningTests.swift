import Foundation
import Testing
@testable import CB21Core

private func text(_ s: String, at time: TimeInterval) -> Clip {
    Clip(representations: [Representation(kind: .plainText, typeIdentifier: "public.utf8-plain-text", data: Data(s.utf8))],
         createdAt: Date(timeIntervalSince1970: time))
}

private func sized(_ name: String, bytes: Int, at time: TimeInterval) -> Clip {
    Clip(representations: [Representation(kind: .plainText, typeIdentifier: "public.utf8-plain-text",
                                          data: Data(repeating: UInt8(ascii: "x"), count: bytes) + Data(name.utf8))],
         createdAt: Date(timeIntervalSince1970: time))
}

private func ids(_ store: ClipStore) async throws -> [UUID] { try await store.list().map(\.id) }

// MARK: Pin and unpin

@Test func clipsAreNotPinnedByDefault() async throws {
    let store = try ClipStore.inMemory()
    try await store.insert(text("a", at: 1))
    #expect(try await store.list().first?.isPinned == false)
}

@Test func pinningAndUnpinningRoundTrips() async throws {
    let store = try ClipStore.inMemory()
    let a = text("a", at: 1)
    try await store.insert(a)
    try await store.pin(id: a.id, at: Date(timeIntervalSince1970: 50))
    let pinned = try await store.list().first
    #expect(pinned?.isPinned == true)
    #expect(pinned?.pinnedAt == Date(timeIntervalSince1970: 50))
    try await store.unpin(id: a.id)
    #expect(try await store.list().first?.isPinned == false)
}

@Test func pinningTwiceKeepsTheFirstPinDate() async throws {
    let store = try ClipStore.inMemory()
    let a = text("a", at: 1)
    try await store.insert(a)
    try await store.pin(id: a.id, at: Date(timeIntervalSince1970: 50))
    try await store.pin(id: a.id, at: Date(timeIntervalSince1970: 99))
    #expect(try await store.list().first?.pinnedAt == Date(timeIntervalSince1970: 50))
}

@Test func pinningOrUnpinningAnUnknownClipThrows() async throws {
    let store = try ClipStore.inMemory()
    await #expect(throws: StoreError.self) { try await store.pin(id: UUID(), at: Date()) }
    await #expect(throws: StoreError.self) { try await store.unpin(id: UUID()) }
}

// MARK: Order

@Test func pinnedClipsComeFirstNewestPinFirstThenTheRestByLastUsed() async throws {
    let store = try ClipStore.inMemory()
    let a = text("a", at: 1), b = text("b", at: 2), c = text("c", at: 3), d = text("d", at: 4)
    for clip in [a, b, c, d] { try await store.insert(clip) }
    try await store.pin(id: a.id, at: Date(timeIntervalSince1970: 100))
    try await store.pin(id: c.id, at: Date(timeIntervalSince1970: 200))
    #expect(try await ids(store) == [c.id, a.id, d.id, b.id])
}

@Test func recopyingAnUnpinnedClipNeverMovesItAbovePinnedOnes() async throws {
    let store = try ClipStore.inMemory()
    let a = text("a", at: 1), b = text("b", at: 2)
    try await store.insert(a)
    try await store.insert(b)
    try await store.pin(id: a.id, at: Date(timeIntervalSince1970: 10))
    try await store.recopy(id: b.id, at: Date(timeIntervalSince1970: 500))
    #expect(try await ids(store) == [a.id, b.id])
}

// MARK: Limits

@Test func limitsNeverEvictAPinnedClip() async throws {
    let store = try ClipStore.inMemory(limits: Limits(maxItems: 2, maxBytes: .max))
    let oldPinned = text("keep me", at: 1)
    try await store.insert(oldPinned)
    try await store.pin(id: oldPinned.id, at: Date(timeIntervalSince1970: 5))
    let b = text("b", at: 2), c = text("c", at: 3)
    _ = try await store.capture(b)
    _ = try await store.capture(c)
    // One slot is taken by the pinned clip, so only the newest other clip fits.
    #expect(try await ids(store) == [oldPinned.id, c.id])
}

@Test func pinnedClipsCountTowardTheStorageTotal() async throws {
    let store = try ClipStore.inMemory(limits: Limits(maxItems: 100, maxBytes: 30))
    let pinned = sized("p", bytes: 14, at: 1)
    try await store.insert(pinned)
    try await store.pin(id: pinned.id, at: Date(timeIntervalSince1970: 5))
    let a = sized("a", bytes: 9, at: 2), b = sized("b", bytes: 9, at: 3)
    _ = try await store.capture(a)
    _ = try await store.capture(b)
    // 15 (pinned) + 10 + 10 = 35 > 30, so the older unpinned clip goes.
    #expect(try await ids(store) == [pinned.id, b.id])
}

@Test func whenPinnedClipsAloneExceedTheLimitsOnlyTheNewestOtherClipIsKept() async throws {
    let store = try ClipStore.inMemory(limits: Limits(maxItems: 1, maxBytes: .max))
    let pinned = text("pinned", at: 1)
    try await store.insert(pinned)
    try await store.pin(id: pinned.id, at: Date(timeIntervalSince1970: 5))
    let a = text("a", at: 2), b = text("b", at: 3)
    _ = try await store.capture(a)
    _ = try await store.capture(b)
    // The pinned clip fills the limit, but a new copy still shows up so it can be reused or pinned.
    #expect(try await ids(store) == [pinned.id, b.id])
}

@Test func loweringALimitReportsOnlyUnpinnedEvictions() async throws {
    let store = try ClipStore.inMemory()
    let pinned = text("p", at: 1)
    try await store.insert(pinned)
    try await store.pin(id: pinned.id, at: Date(timeIntervalSince1970: 5))
    for i in 2...5 { _ = try await store.capture(text("c\(i)", at: TimeInterval(i))) }
    let lower = Limits(maxItems: 3, maxBytes: .max)
    #expect(try await store.evictionCount(for: lower) == 2)
    #expect(try await store.setLimits(lower) == 2)
    let remaining = try await store.list()
    #expect(remaining.count == 3)
    #expect(remaining.first?.id == pinned.id)
}

// MARK: Deleting

@Test func deletingAPinnedClipOnPurposeWorks() async throws {
    let store = try ClipStore.inMemory()
    let a = text("a", at: 1)
    try await store.insert(a)
    try await store.pin(id: a.id, at: Date())
    try await store.delete(ids: [a.id])
    #expect(try await store.count() == 0)
}

@Test func clearAllKeepingPinnedLeavesOnlyThePinnedClips() async throws {
    let store = try ClipStore.inMemory()
    let a = text("a", at: 1), b = text("b", at: 2), c = text("c", at: 3)
    for clip in [a, b, c] { try await store.insert(clip) }
    try await store.pin(id: b.id, at: Date())
    try await store.deleteAll(keepingPinned: true)
    #expect(try await ids(store) == [b.id])
}

@Test func clearAllWithoutKeepingPinnedRemovesEverything() async throws {
    let store = try ClipStore.inMemory()
    let a = text("a", at: 1)
    try await store.insert(a)
    try await store.pin(id: a.id, at: Date())
    try await store.deleteAll()
    #expect(try await store.count() == 0)
}

@Test func clearAllKeepingPinnedOnlyRemovesTheImageFilesOfDeletedClips() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let images = dir.appendingPathComponent("images")
    let store = try ClipStore(path: dir.appendingPathComponent("h.sqlite").path, imagesDirectory: images)
    let keep = Clip(representations: [Representation(kind: .image, typeIdentifier: "public.png", data: Data([1]))], createdAt: Date(timeIntervalSince1970: 1))
    let drop = Clip(representations: [Representation(kind: .image, typeIdentifier: "public.png", data: Data([2]))], createdAt: Date(timeIntervalSince1970: 2))
    try await store.insert(keep)
    try await store.insert(drop)
    try await store.pin(id: keep.id, at: Date())
    try await store.deleteAll(keepingPinned: true)
    #expect(try FileManager.default.contentsOfDirectory(atPath: images.path).count == 1)
    #expect(try await store.list().first?.id == keep.id)
}

// MARK: Duplicate rule unchanged

@Test func duplicateRuleStillComparesWithTheMostRecentlyUsedClipNotThePinnedOne() async throws {
    let store = try ClipStore.inMemory()
    let pinned = text("pinned text", at: 1)
    try await store.insert(pinned)
    try await store.pin(id: pinned.id, at: Date(timeIntervalSince1970: 5))
    _ = try await store.capture(text("latest", at: 2))
    #expect(try await store.capture(text("pinned text", at: 3)) == .stored)
    #expect(try await store.capture(text("pinned text", at: 4)) == .duplicate)
}
