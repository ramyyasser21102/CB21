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
                delete: { service.delete(ids: $0) },
                clearAll: { service.confirmAndClearAll() },
                loadClip: { await service.clip(id: $0) }
            ))
            let window = NSWindow(contentViewController: hosting)
            window.title = "cb21 History"
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
    let delete: (Set<UUID>) -> Void
    let clearAll: () -> Void
    let loadClip: (UUID) async -> Clip?
    @State private var selection = Set<UUID>()

    var body: some View {
        if model.rows.isEmpty {
            ContentUnavailableView("No clips yet", systemImage: "doc.on.clipboard",
                                   description: Text("Things you copy will show up here."))
        } else {
            HSplitView {
            List(model.rows, selection: $selection) { row in
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(Color.accentColor)
                        .opacity(row.id == model.rows.first?.id ? 1 : 0)
                        .help("Most recent clip")
                        .accessibilityHidden(row.id != model.rows.first?.id)
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
            .onDeleteCommand { remove(selection) }
            .toolbar {
                ToolbarItem {
                    Button("Clear All…", action: clearAll)
                }
            }
            .contextMenu(forSelectionType: UUID.self) { ids in
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
            .frame(minWidth: 300, idealWidth: 360)
            DetailPane(selection: selection, load: loadClip)
                .frame(minWidth: 280, idealWidth: 440)
            }
        }
    }

    private func remove(_ ids: Set<UUID>) {
        delete(ids)
        selection.subtract(ids)
    }
}
