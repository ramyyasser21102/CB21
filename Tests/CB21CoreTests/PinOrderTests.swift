import Foundation
import Testing
@testable import CB21Core

private struct Item: Equatable {
    let name: String
    var pinnedAt: Date?
    let lastUsedAt: Date
    var isPinned: Bool { pinnedAt != nil }
}

private func sorted(_ items: [Item]) -> [String] {
    PinOrder.sorted(items, isPinned: \.isPinned, lastUsedAt: \.lastUsedAt).map(\.name)
}

private func at(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

@Test func unpinnedItemsAreNewestUsedFirst() {
    let items = [Item(name: "old", pinnedAt: nil, lastUsedAt: at(1)), Item(name: "new", pinnedAt: nil, lastUsedAt: at(9)), Item(name: "mid", pinnedAt: nil, lastUsedAt: at(5))]
    #expect(sorted(items) == ["new", "mid", "old"])
}

@Test func pinnedItemsComeFirstAndAreOrderedByLastUseLikeTheRest() {
    let items = [
        Item(name: "recent", pinnedAt: nil, lastUsedAt: at(100)),
        Item(name: "pinnedOldUse", pinnedAt: at(20), lastUsedAt: at(1)),
        Item(name: "pinnedNewUse", pinnedAt: at(10), lastUsedAt: at(2)),
        Item(name: "older", pinnedAt: nil, lastUsedAt: at(50)),
    ]
    // The pin dates (20 and 10) play no part: what counts is when each was last used.
    #expect(sorted(items) == ["pinnedNewUse", "pinnedOldUse", "recent", "older"])
}

@Test func aNewlyPinnedOlderClipGoesBelowTheMostRecentlyUsedPinnedClip() {
    // The most recently used clip is pinned and sits first. Pinning another, older clip must not push it down.
    var items = [
        Item(name: "mostRecentPinned", pinnedAt: at(5), lastUsedAt: at(100)),
        Item(name: "other", pinnedAt: nil, lastUsedAt: at(40)),
        Item(name: "older", pinnedAt: nil, lastUsedAt: at(10)),
    ]
    items[2].pinnedAt = at(999) // pinned just now
    #expect(sorted(items) == ["mostRecentPinned", "older", "other"])
}

@Test func pinningAnItemMovesItIntoTheTopGroupRightAway() {
    var items = [Item(name: "a", pinnedAt: nil, lastUsedAt: at(30)), Item(name: "b", pinnedAt: nil, lastUsedAt: at(20)), Item(name: "c", pinnedAt: nil, lastUsedAt: at(10))]
    items[2].pinnedAt = at(99)
    #expect(sorted(items) == ["c", "a", "b"])
}

@Test func unpinningDropsItBackIntoPlaceByLastUsed() {
    var items = [Item(name: "p", pinnedAt: at(5), lastUsedAt: at(25)), Item(name: "a", pinnedAt: nil, lastUsedAt: at(30)), Item(name: "b", pinnedAt: nil, lastUsedAt: at(20))]
    #expect(sorted(items) == ["p", "a", "b"])
    items[0].pinnedAt = nil
    #expect(sorted(items) == ["a", "p", "b"])
}

@Test func equalKeysKeepTheirOriginalOrder() {
    let same = at(7)
    let items = [Item(name: "x", pinnedAt: nil, lastUsedAt: same), Item(name: "y", pinnedAt: nil, lastUsedAt: same), Item(name: "z", pinnedAt: nil, lastUsedAt: same)]
    #expect(sorted(items) == ["x", "y", "z"])
    let pinned = [Item(name: "x", pinnedAt: at(1), lastUsedAt: same), Item(name: "y", pinnedAt: at(2), lastUsedAt: same)]
    #expect(sorted(pinned) == ["x", "y"])
}

@Test func anEmptyListStaysEmpty() {
    #expect(sorted([]).isEmpty)
}

@Test func theOrderMatchesTheStoresOrder() async throws {
    // The store sorts in SQL; the menu re-sorts in memory after a click. They must agree.
    let store = try ClipStore.inMemory()
    func clip(_ s: String, _ t: TimeInterval) -> Clip {
        Clip(representations: [Representation(kind: .plainText, typeIdentifier: "public.utf8-plain-text", data: Data(s.utf8))], createdAt: at(t))
    }
    let a = clip("a", 1), b = clip("b", 2), c = clip("c", 3), d = clip("d", 4)
    for x in [a, b, c, d] { try await store.insert(x) }
    try await store.pin(id: a.id, at: at(100))
    try await store.pin(id: c.id, at: at(200))
    let fromStore = try await store.list()
    let reshuffled = PinOrder.sorted(fromStore.reversed(), isPinned: \.isPinned, lastUsedAt: \.lastUsedAt)
    #expect(reshuffled.map(\.id) == fromStore.map(\.id))
}
