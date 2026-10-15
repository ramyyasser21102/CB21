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
                recopy: { service.recopy(id: $0) }
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
    @State private var selection = Set<UUID>()

    var body: some View {
        if model.rows.isEmpty {
            ContentUnavailableView("No clips yet", systemImage: "doc.on.clipboard",
                                   description: Text("Things you copy will show up here."))
        } else {
            List(model.rows, selection: $selection) { row in
                ClipLabel(row: row).lineLimit(1)
            }
            .contextMenu(forSelectionType: UUID.self) { _ in
            } primaryAction: { ids in
                if let id = ids.first { recopy(id) }
            }
        }
    }
}
