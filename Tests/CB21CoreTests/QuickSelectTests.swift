import Testing
@testable import CB21Core

@Test func firstNineRowsGetTheKeysOneToNine() {
    for index in 0..<9 {
        #expect(QuickSelect.key(forRow: index) == String(index + 1))
    }
}

@Test func rowsBeyondTheNinthAndNegativeRowsGetNoKey() {
    #expect(QuickSelect.key(forRow: 9) == nil)
    #expect(QuickSelect.key(forRow: 40) == nil)
    #expect(QuickSelect.key(forRow: -1) == nil)
}

@Test func keysMapBackToRowIndexes() {
    #expect(QuickSelect.row(forKey: "1") == 0)
    #expect(QuickSelect.row(forKey: "9") == 8)
    #expect(QuickSelect.row(forKey: "0") == nil)
    #expect(QuickSelect.row(forKey: "a") == nil)
    #expect(QuickSelect.row(forKey: "10") == nil)
}

@Test func menuListShowsEveryPinnedClipThenTheMostRecentOthers() {
    struct Item: Equatable { let name: String; let pinned: Bool }
    let items = [Item(name: "p1", pinned: true), Item(name: "a", pinned: false), Item(name: "p2", pinned: true)]
        + (1...15).map { Item(name: "r\($0)", pinned: false) }
    let list = MenuList.split(items, isPinned: \.pinned, recentLimit: 10)
    #expect(list.pinned.map(\.name) == ["p1", "p2"])
    #expect(list.recent.count == 10)
    #expect(list.recent.first?.name == "a")
    #expect(list.recent.last?.name == "r9")
}

@Test func menuListWithNothingPinnedIsJustTheRecentOnes() {
    let list = MenuList.split(Array(1...12), isPinned: { _ in false }, recentLimit: 10)
    #expect(list.pinned.isEmpty)
    #expect(list.recent == Array(1...10))
}

@Test func menuListWithOnlyPinnedClipsHasNoRecentOnes() {
    let list = MenuList.split(["a", "b"], isPinned: { _ in true }, recentLimit: 10)
    #expect(list.pinned == ["a", "b"])
    #expect(list.recent.isEmpty)
}

@Test func menuListKeepsAllPinnedEvenBeyondNine() {
    let list = MenuList.split(Array(1...12), isPinned: { _ in true }, recentLimit: 10)
    #expect(list.pinned.count == 12)
}
