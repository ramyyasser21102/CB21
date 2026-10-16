import AppKit
import CB21Core

/// The search row at the top of the menu: a real search field inside a menu item. The menu window can become key,
/// so the field takes focus as soon as the menu opens and typing, arrow keys and Return all keep working.
final class MenuSearchView: NSView, NSSearchFieldDelegate {
    private let field = MenuSearchField()
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

    /// ⌘1 to ⌘9 while the search field has focus: asked to pick that row; true means it did.
    var onQuickSelect: ((Int) -> Bool)? {
        didSet { field.quickSelect = onQuickSelect }
    }

    func controlTextDidChange(_ obj: Notification) {
        onChange?(field.stringValue)
    }
}


/// The search field. Its cell hands out a text editor that knows ⌘1 to ⌘9.
final class MenuSearchField: NSSearchField {
    var quickSelect: ((Int) -> Bool)? {
        didSet { (cell as? MenuSearchFieldCell)?.quickSelect = quickSelect }
    }

    override class var cellClass: AnyClass? {
        get { MenuSearchFieldCell.self }
        set {}
    }
}

final class MenuSearchFieldCell: NSSearchFieldCell {
    var quickSelect: ((Int) -> Bool)?
    private lazy var editor: QuickSelectFieldEditor = {
        let editor = QuickSelectFieldEditor()
        editor.isFieldEditor = true
        return editor
    }()

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        editor.quickSelect = quickSelect
        return editor
    }
}

/// The text editor behind the search field. With the field focused, a ⌘ shortcut that nothing else claims ends up
/// here and, left alone, makes the error beep. ⌘1 to ⌘9 pick a clip instead.
final class QuickSelectFieldEditor: NSTextView {
    var quickSelect: ((Int) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if handle(event) { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handle(event) || super.performKeyEquivalent(with: event)
    }

    private func handle(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) { KeyLog.write("QuickSelectFieldEditor \(KeyLog.describe(event))") }
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let key = event.charactersIgnoringModifiers, let row = QuickSelect.row(forKey: key) else { return false }
        return quickSelect?(row) == true
    }
}
