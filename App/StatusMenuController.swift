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
    /// The items between the search row and the actions are tagged so they can be swapped while the menu is open.
    private static let clipItemTag = 7001
    private static let searchResultLimit = 20

    init(service: CaptureService) {
        self.service = service
        super.init()
        menu.delegate = self
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
    }

    // MARK: Search

    /// Swaps the clip rows for the ones matching the query. Everything here is synchronous: a menu that is open
    /// doesn't run queued work, so nothing may wait on the database.
    private func rebuildClipItems() {
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
            return model.menuRows.enumerated().map { index, row in
                let entry = clipItem(row)
                if index == 0 { markAsMostRecent(entry) }
                return entry
            }
        }
        let matches = model.rows.filter { ClipSearch.matches(query, in: $0.searchText) }
        if matches.isEmpty { return [note("No matches")] }
        return matches.prefix(Self.searchResultLimit).map { clipItem($0) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
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
        let title: String
        let symbol: String?
        switch row.preview {
        case .text(let text): title = text; symbol = nil
        case .link(let url): title = url; symbol = "link"
        case .file(let name): title = name; symbol = "doc"
        case .image: title = "Image"; symbol = "photo"
        case .pdf: title = "PDF"; symbol = "doc.richtext"
        }
        let entry = item(title) { [service] in service.recopy(id: row.id) }
        if let thumbnail = row.thumbnail {
            entry.image = thumbnail
        } else if let symbol {
            entry.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return entry
    }

    /// A dot in the state column marks the most recently used Clip, as in the History window.
    private func markAsMostRecent(_ entry: NSMenuItem) {
        let config = NSImage.SymbolConfiguration(pointSize: 7, weight: .regular)
        let dot = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Most recent")?
            .withSymbolConfiguration(config)
        entry.onStateImage = dot
        entry.state = .on
        entry.toolTip = "Most recent clip"
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
