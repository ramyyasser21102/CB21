import Foundation
import Testing
@testable import CB21Core

private enum Key {
    static let space: UInt16 = 49, tab: UInt16 = 48, q: UInt16 = 12, c: UInt16 = 8
    static let v: UInt16 = 9, three: UInt16 = 20, four: UInt16 = 21, h: UInt16 = 4, escape: UInt16 = 53
}

@Test func shortcutWithoutCommandControlOrOptionIsRejected() {
    #expect(ShortcutValidator.validate(Shortcut(keyCode: Key.v, modifiers: [])) == .needsModifier)
    #expect(ShortcutValidator.validate(Shortcut(keyCode: Key.v, modifiers: [.shift])) == .needsModifier)
}

@Test(arguments: [
    Shortcut(keyCode: Key.space, modifiers: [.command]),
    Shortcut(keyCode: Key.tab, modifiers: [.command]),
    Shortcut(keyCode: Key.q, modifiers: [.command]),
    Shortcut(keyCode: Key.c, modifiers: [.command]),
    Shortcut(keyCode: Key.v, modifiers: [.command]),
    Shortcut(keyCode: Key.three, modifiers: [.command, .shift]),
    Shortcut(keyCode: Key.four, modifiers: [.command, .shift]),
    Shortcut(keyCode: Key.escape, modifiers: [.command, .option]),
    Shortcut(keyCode: Key.q, modifiers: [.command, .control]),
])
func knownSystemShortcutsAreRejected(shortcut: Shortcut) {
    #expect(ShortcutValidator.validate(shortcut) == .systemReserved)
}

@Test func ordinaryShortcutIsAccepted() {
    #expect(ShortcutValidator.validate(Shortcut(keyCode: Key.v, modifiers: [.command, .shift])) == nil)
    #expect(ShortcutValidator.validate(Shortcut(keyCode: Key.h, modifiers: [.control, .option])) == nil)
}

@Test func shortcutAlreadyUsedByAnotherCb21ActionIsRejected() {
    let taken = Shortcut(keyCode: Key.v, modifiers: [.command, .shift])
    #expect(ShortcutValidator.validate(taken, takenByOtherActions: [taken]) == .alreadyUsed)
    let other = Shortcut(keyCode: Key.v, modifiers: [.command, .option])
    #expect(ShortcutValidator.validate(taken, takenByOtherActions: [other]) == nil)
}

@Test func shortcutSurvivesEncodingAndDecoding() throws {
    let shortcut = Shortcut(keyCode: Key.v, modifiers: [.command, .shift])
    let data = try JSONEncoder().encode(shortcut)
    #expect(try JSONDecoder().decode(Shortcut.self, from: data) == shortcut)
}
