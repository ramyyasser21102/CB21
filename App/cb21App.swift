import SwiftUI
import CB21Core

@main
struct CB21App: App {
    private let service = CaptureService.shared

    init() {
        CaptureService.shared.start()
    }

    var body: some Scene {
        MenuBarExtra("cb21", systemImage: "doc.on.clipboard") {
            MenuContent(
                model: service.model,
                recopy: { id in service.recopy(id: id) },
                openHistory: { HistoryWindowController.shared.show(service: service) },
                clearAll: { service.confirmAndClearAll() },
                openSettings: { SettingsWindowController.shared.show(service: service) }
            )
        }
    }
}

struct MenuContent: View {
    let model: HistoryModel
    let recopy: (UUID) -> Void
    let openHistory: () -> Void
    let clearAll: () -> Void
    let openSettings: () -> Void

    var body: some View {
        if model.pasteboardAccessDenied {
            Text("cb21 can't read the clipboard").disabled(true)
            Button("Allow in System Settings…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
        }
        ForEach(model.notices, id: \.self) { notice in
            Text(message(for: notice)).disabled(true)
            Button("Dismiss") { model.dismiss(notice) }
            Divider()
        }
        if model.rows.isEmpty {
            Text("No clips yet").disabled(true)
        } else {
            ForEach(model.menuRows) { row in
                Button { recopy(row.id) } label: { ClipLabel(row: row) }
            }
        }
        Divider()
        Button("Open history…", action: openHistory)
        Button("Clear all…", action: clearAll)
            .disabled(model.rows.isEmpty)
        Button("Settings…", action: openSettings)
            .keyboardShortcut(",")
        Button("Quit cb21") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func message(for notice: HistoryModel.Notice) -> String {
        switch notice {
        case .clipTooLarge: "A copy was too large for the storage limit and was not saved"
        case .databaseRecovered: "History was damaged and has been reset; the old file was kept"
        }
    }
}

/// One Clip's preview line, shared by the menu and the History window.
struct ClipLabel: View {
    let row: HistoryModel.Row

    @ViewBuilder
    var body: some View {
        switch row.preview {
        case .text(let text):
            Text(text)
        case .link(let url):
            Label(url, systemImage: "link")
        case .file(let name):
            Label(name, systemImage: "doc")
        case .image:
            if let thumbnail = row.thumbnail {
                Label { Text("Image") } icon: { Image(nsImage: thumbnail) }
            } else {
                Label("Image", systemImage: "photo")
            }
        }
    }
}
