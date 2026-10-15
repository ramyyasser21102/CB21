/// Decides whether a press of the "open menu" shortcut should open the menu.
///
/// Opening the menu from code blocks until it closes, and presses made meanwhile queue up and reopen it
/// one after another. This gate drops a press when the menu is open or already on its way open.
public struct MenuOpenGate: Sendable {
    private var busy = false

    public init() {}

    /// Call at the moment of the key press. True means: open the menu.
    public mutating func acceptShortcutPress() -> Bool {
        guard !busy else { return false }
        busy = true
        return true
    }

    /// The menu appeared, from the shortcut or from a mouse click.
    public mutating func menuDidOpen() { busy = true }

    public mutating func menuDidClose() { busy = false }

    /// The code that opened the menu has returned, whether or not a menu appeared.
    public mutating func openFinished() { busy = false }
}
