import AppKit
import SwiftUI
import CB21Core

/// The floating panel that shows the full History.
@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()

    private var window: NSWindow?

    private var hosting: NSHostingView<HistoryView>?

    func show(service: CaptureService) {
        if window == nil {
            let hosting = NSHostingView(rootView: makeRoot(service: service, idealSize: Self.minimumSize))
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: Self.minimumSize),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.contentView = hosting
            window.title = "CB21 History"
            window.level = .floating
            window.isReleasedWhenClosed = false
            self.hosting = hosting
            self.window = window
        }
        // Every time it is opened (not when it is just brought to the front): a spacious size, in the middle of
        // the screen the pointer is on.
        if let window, let hosting, !window.isVisible {
            let frame = Self.openingFrame()
            // SwiftUI sizes the window to its content's ideal size, so the ideal size is the one chosen here.
            // Without it the window opened as small as the "No clips yet" message (400 x 210).
            hosting.rootView = makeRoot(service: service, idealSize: window.contentRect(forFrameRect: frame).size)
            window.setFrame(frame, display: false)
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if let window {
            // The toolbar SwiftUI adds once there are clips changes the window's height after it was centered,
            // so centre it again, once, when it has settled.
            let opened = window.frame
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                guard window.isVisible, abs(window.frame.minX - opened.minX) < 2 else { return }
                let screen = window.screen ?? NSScreen.main
                if let visible = screen?.visibleFrame {
                    window.setFrame(WindowPlacement.centered(size: window.frame.size, in: visible), display: true)
                }
            }
        }
    }

    private static let minimumSize = CGSize(width: 720, height: 480)

    private func makeRoot(service: CaptureService, idealSize: CGSize) -> HistoryView {
        HistoryView(
            model: service.model,
            idealSize: idealSize,
            minimumSize: Self.minimumSize,
            copy: { id in
                service.recopy(id: id)
                HistoryWindowController.shared.hide()
            },
            delete: { service.confirmAndDelete(ids: $0) },
            setPinned: { service.setPinned($0, $1) },
            clearAll: { service.confirmAndClearAll() },
            loadClip: { await service.clip(id: $0) },
            folderAccess: service.folderAccess
        )
    }

    private static func openingFrame() -> NSRect {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main ?? NSScreen.screens[0]
        return WindowPlacement.centeredFrame(
            in: screen.visibleFrame,
            widthFraction: 0.62, heightFraction: 0.74,
            minimum: CGSize(width: 860, height: 600), maximum: CGSize(width: 1100, height: 860)
        )
    }

    /// Closes the window and hands focus back to the app the user came from, ready to paste.
    func hide() {
        window?.orderOut(nil)
        NSApp.hide(nil)
    }

    func toggle(service: CaptureService) {
        if let window, window.isVisible, window.isKeyWindow {
            window.orderOut(nil)
        } else {
            show(service: service)
        }
    }
}

struct HistoryView: View {
    let model: HistoryModel
    /// The size the window opens at, and the smallest it may be resized to.
    let idealSize: CGSize
    let minimumSize: CGSize
    /// Puts the Clip on the pasteboard, makes it the most recent, and closes the window.
    let copy: (UUID) -> Void
    /// Deletes Clips, asking first when a pinned one is included. True when they were deleted.
    let delete: (Set<UUID>) -> Bool
    let setPinned: (UUID, Bool) -> Void
    let clearAll: () -> Void
    let loadClip: (UUID) async -> Clip?
    let folderAccess: FolderAccessModel
    @State private var selection = Set<UUID>()
    @State private var query = ""

    /// Pinned clips first (the list is already in that order), narrowed by the search.
    private var visibleRows: [HistoryModel.Row] {
        model.rows.filter { ClipSearch.matches(query, in: $0.searchText) }
    }

    var body: some View {
        Group {
            if model.rows.isEmpty {
                ContentUnavailableView("No clips yet", systemImage: "doc.on.clipboard",
                                       description: Text("Things you copy will show up here."))
            } else {
                HSplitView {
                    listPane
                        .frame(minWidth: 300, idealWidth: 360)
                    DetailPane(selection: selection, load: loadClip, folderAccess: folderAccess)
                        .frame(minWidth: 280, idealWidth: 440)
                }
            }
        }
        .frame(minWidth: minimumSize.width, idealWidth: idealSize.width, maxWidth: .infinity,
               minHeight: minimumSize.height, idealHeight: idealSize.height, maxHeight: .infinity)
    }

    private var listPane: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if visibleRows.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                list
            }
        }
        .background { quickSelectShortcuts }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search clips")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var list: some View {
        let rows = visibleRows
        let pinned = rows.filter(\.isPinned)
        let others = rows.filter { !$0.isPinned }
        return List(selection: $selection) {
            if pinned.isEmpty {
                ForEach(others) { row in rowView(row, number: rows.firstIndex { $0.id == row.id }) }
            } else {
                Section("Pinned") {
                    ForEach(pinned) { row in rowView(row, number: rows.firstIndex { $0.id == row.id }) }
                }
                Section("Clips") {
                    ForEach(others) { row in rowView(row, number: rows.firstIndex { $0.id == row.id }) }
                }
            }
        }
        .onDeleteCommand { remove(selection) }
        .toolbar {
            ToolbarItem {
                Button("Clear All…", action: clearAll)
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if ids.count == 1, let id = ids.first, let row = model.rows.first(where: { $0.id == id }) {
                Button(row.isPinned ? "Unpin" : "Pin") { setPinned(id, !row.isPinned) }
            }
            if !ids.isEmpty {
                Button(ids.count == 1 ? "Delete" : "Delete \(ids.count) Clips", role: .destructive) {
                    remove(ids)
                }
            }
        } primaryAction: { ids in
            if let id = ids.first { copy(id) }
        }
        .safeAreaInset(edge: .bottom) {
            if selection.count > 1 {
                HStack {
                    Text("\(selection.count) selected")
                    Spacer()
                    Button("Delete Selected", role: .destructive) { remove(selection) }
                }
                .padding(8)
                .background(.bar)
            }
        }
    }

    private func rowView(_ row: HistoryModel.Row, number: Int?) -> some View {
        HStack {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(Color.accentColor)
                .opacity(row.id == model.mostRecentID ? 1 : 0)
                .help("Most recent clip")
                .accessibilityHidden(row.id != model.mostRecentID)
                .accessibilityLabel("Most recent")
            VStack(alignment: .leading, spacing: 2) {
                ClipLabel(row: row).lineLimit(1)
                // Re-evaluated every 30 s so "5 min ago" doesn't go stale while the window is open.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(ClipSubtitle.make(
                        createdAt: row.createdAt, byteCount: row.byteCount,
                        sourceAppName: row.sourceAppName, now: context.date
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            Spacer()
            if let number, let key = QuickSelect.key(forRow: number) {
                Text("⌘\(key)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            Button {
                setPinned(row.id, !row.isPinned)
            } label: {
                Image(systemName: row.isPinned ? "star.fill" : "star")
                    .foregroundStyle(row.isPinned ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(row.isPinned ? "Unpin this clip" : "Pin this clip to the top")
            .accessibilityLabel(row.isPinned ? "Unpin clip" : "Pin clip")
            Button {
                copy(row.id)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy this clip and close")
            .accessibilityLabel("Copy clip")
            Button {
                remove([row.id])
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete this clip")
            .accessibilityLabel("Delete clip")
        }
    }

    /// ⌘1 to ⌘9 copy the Nth visible clip and close the window; ⌥⌘1 to ⌥⌘9 pin or unpin it. The buttons are
    /// invisible and exist only to carry the shortcuts, which follow whatever the search leaves visible.
    private var quickSelectShortcuts: some View {
        ZStack {
            ForEach(Array(visibleRows.prefix(QuickSelect.maxRows).enumerated()), id: \.element.id) { index, row in
                if let key = QuickSelect.key(forRow: index), let character = key.first {
                    Button("Copy clip \(key)") { copy(row.id) }
                        .keyboardShortcut(KeyEquivalent(character), modifiers: .command)
                    Button("Pin or unpin clip \(key)") { setPinned(row.id, !row.isPinned) }
                        .keyboardShortcut(KeyEquivalent(character), modifiers: [.command, .option])
                }
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func remove(_ ids: Set<UUID>) {
        if delete(ids) { selection.subtract(ids) }
    }
}
