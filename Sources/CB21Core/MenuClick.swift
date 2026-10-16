/// What choosing a clip in the menu does. Holding ⌥ pins or unpins it instead of copying it.
///
/// The menu also swaps the row's title to "Pin…" while ⌥ is held, but that swap is macOS's to do and can be missed
/// (for example while the search field has focus), so the choice is made from the key state at the moment of the click.
public enum MenuClick {
    public enum Intent: Sendable, Equatable {
        case copy, pin, unpin
    }

    public static func intent(optionHeld: Bool, isPinned: Bool) -> Intent {
        guard optionHeld else { return .copy }
        return isPinned ? .unpin : .pin
    }
}
