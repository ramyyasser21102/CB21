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
                recopy: { service.recopy(id: $0) },
                delete: { service.delete(ids: $0) },
                clearAll: { service.confirmAndClearAll() }
            ))
            let window = NSWindow(contentViewController: hosting)
            window.title = "cb21 History"
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.level = .floating
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 420, height: 520))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
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
    let recopy: (UUID) -> Void
    let delete: (Set<UUID>) -> Void
    let clearAll: () -> Void
    @State private var selection = Set<UUID>()

    var body: some View {
        if model.rows.isEmpty {
            ContentUnavailableView("No clips yet", systemImage: "doc.on.clipboard",
                                   description: Text("Things you copy will show up here."))
        } else {
            List(model.rows, selection: $selection) { row in
                HStack {
                    ClipLabel(row: row).lineLimit(1)
                    Spacer()
                    Button {
                        remove([row.id])
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete this clip")
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
                if let id = ids.first { recopy(id) }
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
    }

    private func remove(_ ids: Set<UUID>) {
        delete(ids)
        selection.subtract(ids)
    }
}
