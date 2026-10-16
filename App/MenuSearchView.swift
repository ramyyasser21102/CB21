import AppKit

/// The search row at the top of the menu: a real search field inside a menu item. The menu window can become key,
/// so the field takes focus as soon as the menu opens and typing, arrow keys and Return all keep working.
final class MenuSearchView: NSView, NSSearchFieldDelegate {
    private let field = NSSearchField()
    /// Called on every change, synchronously: a menu that is open doesn't run queued work.
    var onChange: ((String) -> Void)?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 32))
        field.placeholderString = "Search"
        field.delegate = self
        field.setAccessibilityLabel("Search clips")
        field.translatesAutoresizingMaskIntoConstraints = false
        addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func clear() {
        field.stringValue = ""
    }

    override func viewDidMoveToWindow() {
        guard window != nil else { return }
        // Not DispatchQueue.main: that isn't serviced while a menu is open. Common run loop modes are.
        CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self.field)
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    func controlTextDidChange(_ obj: Notification) {
        onChange?(field.stringValue)
    }
}
