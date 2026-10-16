import Testing
@testable import CB21Core

@Test func plainClickOnARowCopiesIt() {
    #expect(MenuClick.intent(optionHeld: false, isPinned: false) == .copy)
    #expect(MenuClick.intent(optionHeld: false, isPinned: true) == .copy)
}

@Test func optionClickOnAnUnpinnedRowPinsIt() {
    #expect(MenuClick.intent(optionHeld: true, isPinned: false) == .pin)
}

@Test func optionClickOnAPinnedRowUnpinsIt() {
    #expect(MenuClick.intent(optionHeld: true, isPinned: true) == .unpin)
}
