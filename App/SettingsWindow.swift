import AppKit
import SwiftUI
import CB21Core

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(settings: SettingsModel) {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
            window.title = "cb21 Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let settings: SettingsModel

    var body: some View {
        Form {
            Section("Shortcuts") {
                Text("No shortcuts set").foregroundStyle(.secondary)
            }
            Section("History") {
                LabeledContent("Keep at most", value: "\(settings.values.limits.maxItems) clips")
                LabeledContent("Storage limit", value: "\(settings.values.limits.maxBytes / (1024 * 1024)) MB")
            }
            Section("General") {
                Text("Nothing to configure yet").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 300)
    }
}
