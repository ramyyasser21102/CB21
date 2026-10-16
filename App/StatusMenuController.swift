import AppKit
import CB21Core

/// The menu bar icon and its menu. The menu is rebuilt each time it opens, so it is always current.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let service: CaptureService
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var openGate = MenuOpenGate()
    private let searchView = MenuSearchView()
    private var searchQuery = ""
    private var rowViews: [ObjectIdentifier: ClipMenuRowView] = [:]
    /// What to do once the menu has closed, after a click on a row.
    private var pendingAfterClose: (() -> Void)?
    /// The items between the search row and the actions are tagged so they can be swapped while the menu is open.
    private static let clipItemTag = 7001
    private static let searchResultLimit = 20

    init(service: CaptureService) {
        self.service = service
        super.init()
        menu.delegate = self
        // The menu's width is set here, not by the longest clip. Rows and the search field stretch to it.
        menu.minimumWidth = ClipMenuRowView.size.width
        searchView.onQuickSelect = { [weak self] row in self?.quickSelect(row: row) ?? false }
        searchView.onChange = { [weak self] query in
            self?.searchQuery = query
            self?.rebuildClipItems()
        }
        statusItem.menu = menu
        statusItem.button?.image = Self.icon(paused: false)
        statusItem.button?.setAccessibilityLabel("CB21 clipboard history")
        service.model.onPausedChange = { [weak self] paused in
            self?.statusItem.button?.image = Self.icon(paused: paused)
        }
    }

    /// Called when the shortcut is pressed. False means the menu is open or opening, so the press is dropped.
    func shouldOpenFromShortcut() -> Bool {
        openGate.acceptShortcutPress()
    }

    /// Opens the menu as if the icon had been clicked. This blocks until the menu closes.
    func openMenu() {
        defer { openGate.openFinished() }
        statusItem.button?.performClick(nil)
    }

    private static func icon(paused: Bool) -> NSImage? {
        let image = NSImage(named: paused ? "MenuBarPaused" : "MenuBarDefault")
        image?.isTemplate = true
        image?.size = NSSize(width: image.map { 18 * $0.size.width / $0.size.height } ?? 14, height: 18)
        return image
    }

    // MARK: NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        openGate.menuDidOpen()
    }

    func menuDidClose(_ menu: NSMenu) {
        openGate.menuDidClose()
        searchQuery = ""
        searchView.clear()
        if let pending = pendingAfterClose {
            pendingAfterClose = nil
            pending()
        }
    }

    // MARK: Quick select (⌘1 to ⌘9)

    /// The clip rows in the order shown, which is the order of ⌘1 to ⌘9.
    private func clipRowItems() -> [NSMenuItem] {
        menu.items.filter { rowViews[ObjectIdentifier($0)] != nil }
    }

    /// ⌘1 to ⌘9, called by the search field's text editor (`QuickSelectFieldEditor`), which is where the key ends up
    /// while the field has focus. Picking a row closes the menu first, then copies, like a click.
    private func quickSelect(row: Int) -> Bool {
        KeyLog.write("quickSelect row=\(row + 1) rowsListed=\(clipRowItems().count)")
        let items = clipRowItems()
        guard row < items.count, let view = rowViews[ObjectIdentifier(items[row])] else { return false }
        view.onPick?(false)
        return true
    }

    /// A custom row view has to draw the highlight itself, so tell each row whether it is the highlighted one.
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for (id, view) in rowViews {
            view.isHighlighted = item.map { ObjectIdentifier($0) == id } ?? false
        }
    }

    // MARK: Search

    /// Swaps the clip rows for the ones matching the query. Everything here is synchronous: a menu that is open
    /// doesn't run queued work, so nothing may wait on the database.
    private func rebuildClipItems() {
        rowViews.removeAll()
        guard let firstSlot = menu.items.firstIndex(where: { $0.tag == Self.clipItemTag }) else { return }
        for item in menu.items.reversed() where item.tag == Self.clipItemTag {
            menu.removeItem(item)
        }
        for (offset, entry) in clipEntries().enumerated() {
            entry.tag = Self.clipItemTag
            menu.insertItem(entry, at: firstSlot + offset)
        }
    }

    private func clipEntries() -> [NSMenuItem] {
        let model = service.model
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            if model.menuRows.isEmpty { return [note("No clips yet")] }
            return entries(for: model.menuRows)
        }
        let matches = model.rows.filter { ClipSearch.matches(query, in: $0.searchText) }
        if matches.isEmpty { return [note("No matches")] }
        return entries(for: Array(matches.prefix(Self.searchResultLimit)))
    }

    /// One menu row per Clip, drawn by `ClipMenuRowView` with its own star. Pinned rows come first (the list is already
    /// in that order) and a divider separates them from the rest. The first nine rows answer to ⌘1 to ⌘9; the numbers
    /// follow what is listed, so they restart when a search narrows it.
    private func entries(for rows: [HistoryModel.Row]) -> [NSMenuItem] {
        let mostRecent = service.model.mostRecentID
        var result: [NSMenuItem] = []
        var previousPinned: Bool?
        for (index, row) in rows.enumerated() {
            if let previousPinned, previousPinned != row.isPinned { result.append(.separator()) }
            previousPinned = row.isPinned
            let primary = clipItem(row)
            // The row draws its own ⌘ number. The key itself is handled by `quickSelect`, not by a key equivalent on the
            // item: for a row with a custom view the window matches the key equivalent, claims the key and then runs
            // nothing, so ⌘1 to ⌘9 did nothing.
            let key = QuickSelect.key(forRow: index)
            let (title, symbol) = Self.titleAndSymbol(for: row)
            let view = ClipMenuRowView(.init(
                title: title, symbol: symbol, thumbnail: row.thumbnail, number: key,
                isMostRecent: row.id == mostRecent, isPinned: row.isPinned
            ))
            view.onPick = { [weak self] optionHeld in
                // Closing the menu first: this runs inside the menu's own event loop, and the action must not.
                self?.pendingAfterClose = { [service = self?.service] in
                    switch MenuClick.intent(optionHeld: optionHeld, isPinned: view.isPinned) {
                    case .copy: service?.recopy(id: row.id)
                    case .pin: service?.setPinned(row.id, true)
                    case .unpin: service?.setPinned(row.id, false)
                    }
                }
                self?.menu.cancelTracking()
            }
            view.onTogglePin = { [weak self] pinned in
                guard let self else { return }
                // The list reorders at once, in memory: a pinned clip jumps into the pinned group and an unpinned one
                // drops back into the list. The database write is queued by `setPinned` and runs after the menu closes.
                self.service.model.setPinnedOptimistically(row.id, pinned: pinned)
                self.service.setPinned(row.id, pinned)
                self.rebuildClipItems()
            }
            // The menu sizes itself to the widest item title, even for an item with a custom view, so a long clip
            // would widen the whole menu. The row draws its own text; this short title is only a fallback.
            primary.title = String(title.prefix(24))
            primary.view = view
            rowViews[ObjectIdentifier(primary)] = view
            result.append(primary)
        }
        return result
    }


    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        rowViews.removeAll()
        let model = service.model
        searchQuery = ""
        searchView.clear()
        let searchItem = NSMenuItem()
        searchItem.view = searchView
        menu.addItem(searchItem)
        menu.addItem(.separator())

        if model.pasteboardAccessDenied {
            menu.addItem(note("CB21 can't read the clipboard"))
            menu.addItem(item("Allow in System Settings…") {
                if let url = URL(string: SystemSettingsLink.pasteboard) {
                    NSWorkspace.shared.open(url)
                }
            })
            menu.addItem(.separator())
        }
        for notice in model.notices {
            menu.addItem(note(Self.message(for: notice)))
            menu.addItem(item("Dismiss") { model.dismiss(notice) })
            menu.addItem(.separator())
        }

        for entry in clipEntries() {
            entry.tag = Self.clipItemTag
            menu.addItem(entry)
        }
        menu.addItem(.separator())

        menu.addItem(item("Open history…") { [service] in HistoryWindowController.shared.show(service: service) })
        if model.isPaused {
            menu.addItem(item("Resume capture") { [service] in service.setPause(nil) })
        } else {
            let pause = NSMenuItem(title: "Pause capture", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            submenu.addItem(item("Pause for 5 minutes") { [service] in service.setPause(.minutes(5)) })
            submenu.addItem(item("Pause for 15 minutes") { [service] in service.setPause(.minutes(15)) })
            submenu.addItem(item("Pause until resumed") { [service] in service.setPause(.untilResumed) })
            pause.submenu = submenu
            menu.addItem(pause)
        }
        let clear = item("Clear all…") { [service] in service.confirmAndClearAll() }
        clear.isEnabled = !model.rows.isEmpty
        menu.addItem(clear)
        menu.addItem(item("Settings…", key: ",") { [service] in SettingsWindowController.shared.show(service: service) })
        menu.addItem(item("Welcome…") { [service] in WelcomeWindowController.shared.show(service: service) })
        menu.addItem(item("Quit CB21", key: "q") { NSApp.terminate(nil) })
    }

    // MARK: Items

    private func clipItem(_ row: HistoryModel.Row) -> NSMenuItem {
        let (title, _) = Self.titleAndSymbol(for: row)
        // The action covers Return on a highlighted row and ⌘1 to ⌘9; clicks are handled by the row view.
        return item(title) { [service] in
            switch MenuClick.intent(optionHeld: NSEvent.modifierFlags.contains(.option), isPinned: row.isPinned) {
            case .copy: service.recopy(id: row.id)
            case .pin: service.setPinned(row.id, true)
            case .unpin: service.setPinned(row.id, false)
            }
        }
    }

    private static func titleAndSymbol(for row: HistoryModel.Row) -> (String, String?) {
        switch row.preview {
        case .text(let text): (text, nil)
        case .link(let url): (url, "link")
        case .file(let name): (name, "doc")
        case .image: ("Image", nil)
        case .pdf: ("PDF", "doc.richtext")
        }
    }

    private func note(_ text: String) -> NSMenuItem {
        let note = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        note.isEnabled = false
        return note
    }

    private func item(_ title: String, key: String = "", action: @escaping () -> Void) -> NSMenuItem {
        ClosureMenuItem(title: title, key: key, action: action)
    }

    private static func message(for notice: HistoryModel.Notice) -> String {
        switch notice {
        case .clipTooLarge: "A copy was too large for the storage limit and was not saved"
        case .databaseRecovered: "History was damaged and has been reset; the old file was kept"
        }
    }
}

/// A menu item that runs a closure when chosen.
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, key: String, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func run() { handler() }
}
