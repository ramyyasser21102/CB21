import Foundation

public struct ShortcutModifiers: OptionSet, Sendable, Hashable, Codable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = ShortcutModifiers(rawValue: 1 << 0)
    public static let control = ShortcutModifiers(rawValue: 1 << 1)
    public static let option = ShortcutModifiers(rawValue: 1 << 2)
    public static let shift = ShortcutModifiers(rawValue: 1 << 3)
}

/// A key (virtual key code) plus modifiers.
public struct Shortcut: Sendable, Hashable, Codable {
    public let keyCode: UInt16
    public let modifiers: ShortcutModifiers

    public init(keyCode: UInt16, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum ShortcutProblem: Sendable, Equatable {
    /// Needs at least one of Command, Control or Option.
    case needsModifier
    case systemReserved
    case alreadyUsed
}

/// Checks a shortcut before it is bound. macOS has no API listing other apps' shortcuts,
/// so only system-reserved shortcuts and cb21's own can be detected.
public enum ShortcutValidator {
    public static func validate(_ shortcut: Shortcut, takenByOtherActions: [Shortcut] = []) -> ShortcutProblem? {
        if shortcut.modifiers.isDisjoint(with: [.command, .control, .option]) {
            return .needsModifier
        }
        if reserved.contains(shortcut) {
            return .systemReserved
        }
        if takenByOtherActions.contains(shortcut) {
            return .alreadyUsed
        }
        return nil
    }

    private static let reserved: Set<Shortcut> = {
        // ANSI virtual key codes.
        let space: UInt16 = 49, tab: UInt16 = 48, grave: UInt16 = 50, escape: UInt16 = 53
        let q: UInt16 = 12, w: UInt16 = 13, h: UInt16 = 4, m: UInt16 = 46, d: UInt16 = 2
        let a: UInt16 = 0, c: UInt16 = 8, v: UInt16 = 9, x: UInt16 = 7, z: UInt16 = 6
        let three: UInt16 = 20, four: UInt16 = 21, five: UInt16 = 23
        return [
            Shortcut(keyCode: space, modifiers: [.command]),
            Shortcut(keyCode: space, modifiers: [.control]),
            Shortcut(keyCode: space, modifiers: [.command, .option]),
            Shortcut(keyCode: space, modifiers: [.command, .control]),
            Shortcut(keyCode: tab, modifiers: [.command]),
            Shortcut(keyCode: grave, modifiers: [.command]),
            Shortcut(keyCode: escape, modifiers: [.command, .option]),
            Shortcut(keyCode: q, modifiers: [.command]),
            Shortcut(keyCode: q, modifiers: [.command, .control]),
            Shortcut(keyCode: q, modifiers: [.command, .shift]),
            Shortcut(keyCode: w, modifiers: [.command]),
            Shortcut(keyCode: h, modifiers: [.command]),
            Shortcut(keyCode: h, modifiers: [.command, .option]),
            Shortcut(keyCode: m, modifiers: [.command]),
            Shortcut(keyCode: d, modifiers: [.command, .option]),
            Shortcut(keyCode: a, modifiers: [.command]),
            Shortcut(keyCode: c, modifiers: [.command]),
            Shortcut(keyCode: v, modifiers: [.command]),
            Shortcut(keyCode: x, modifiers: [.command]),
            Shortcut(keyCode: z, modifiers: [.command]),
            Shortcut(keyCode: three, modifiers: [.command, .shift]),
            Shortcut(keyCode: four, modifiers: [.command, .shift]),
            Shortcut(keyCode: five, modifiers: [.command, .shift]),
        ]
    }()
}
