import AppKit
import SwiftUI
import CB21Core

/// The floating panel that shows the full History.
@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()

    private var window: NSWindow?

    func show(service: CaptureService) {
        if window == nil {
            let hosting = NSHostingController(rootView: HistoryView(
                model: service.model,
                copy: { id in
                    service.recopy(id: id)
                    HistoryWindowController.shared.hide()
                },
                delete: { service.confirmAndDelete(ids: $0) },
                setPinned: { service.setPinned($0, $1) },
                clearAll: { service.confirmAndClearAll() },
                loadClip: { await service.clip(id: $0) }
            ))
            let window = NSWindow(contentViewController: hosting)
            window.title = "CB21 History"
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.level = .floating
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 800, height: 540))
            window.contentMinSize = NSSize(width: 640, height: 360)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
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
    /// Puts the Clip on the pasteboard, makes it the most recent, and closes the window.
    let copy: (UUID) -> Void
    /// Deletes Clips, asking first when a pinned one is included. True when they were deleted.
    let delete: (Set<UUID>) -> Bool
    let setPinned: (UUID, Bool) -> Void
    let clearAll: () -> Void
    let loadClip: (UUID) async -> Clip?
    @State private var selection = Set<UUID>()
    @State private var query = ""

    /// Pinned clips first (the list is already in that order), narrowed by the search.
    private var visibleRows: [HistoryModel.Row] {
        model.rows.filter { ClipSearch.matches(query, in: $0.searchText) }
    }

    var body: some View {
        if model.rows.isEmpty {
            ContentUnavailableView("No clips yet", systemImage: "doc.on.clipboard",
                                   description: Text("Things you copy will show up here."))
        } else {
            HSplitView {
                listPane
                    .frame(minWidth: 300, idealWidth: 360)
                DetailPane(selection: selection, load: loadClip)
                    .frame(minWidth: 280, idealWidth: 440)
            }
        }
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
