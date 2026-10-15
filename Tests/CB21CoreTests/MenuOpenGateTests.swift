import Testing
@testable import CB21Core

@Test func firstShortcutPressIsAccepted() {
    var gate = MenuOpenGate()
    let accepted = gate.acceptShortcutPress()
    #expect(accepted)
}

@Test func pressesWhileTheMenuIsOpeningOrOpenAreDropped() {
    var gate = MenuOpenGate()
    let first = gate.acceptShortcutPress()
    // Hammering the shortcut before and after the menu appears must not queue more opens.
    let beforeItAppears = gate.acceptShortcutPress()
    gate.menuDidOpen()
    let whileOpen = gate.acceptShortcutPress()
    let stillOpen = gate.acceptShortcutPress()
    #expect(first)
    #expect(!beforeItAppears)
    #expect(!whileOpen)
    #expect(!stillOpen)
}

@Test func shortcutWorksAgainOnceTheMenuHasClosed() {
    var gate = MenuOpenGate()
    _ = gate.acceptShortcutPress()
    gate.menuDidOpen()
    gate.menuDidClose()
    gate.openFinished()
    let again = gate.acceptShortcutPress()
    #expect(again)
}

@Test func menuOpenedWithTheMouseAlsoBlocksTheShortcut() {
    var gate = MenuOpenGate()
    gate.menuDidOpen()
    let whileOpen = gate.acceptShortcutPress()
    gate.menuDidClose()
    let afterClose = gate.acceptShortcutPress()
    #expect(!whileOpen)
    #expect(afterClose)
}

@Test func anOpenThatNeverShowedTheMenuDoesNotLockTheShortcut() {
    var gate = MenuOpenGate()
    _ = gate.acceptShortcutPress()
    gate.openFinished() // the click returned without a menu ever opening
    let again = gate.acceptShortcutPress()
    #expect(again)
}
