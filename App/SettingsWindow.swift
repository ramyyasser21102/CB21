import AppKit
import SwiftUI
import CB21Core

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var applyLimits: ((Limits) async -> Bool)?

    func show(settings: SettingsModel, applyLimits: @escaping (Limits) async -> Bool) {
        self.applyLimits = applyLimits
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings, applyLimits: { await self.applyLimits?($0) ?? false })))
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
    let applyLimits: (Limits) async -> Bool

    @State private var maxItems: Int
    @State private var maxMegabytes: Int

    private static let bytesPerMegabyte = 1024 * 1024

    init(settings: SettingsModel, applyLimits: @escaping (Limits) async -> Bool) {
        self.settings = settings
        self.applyLimits = applyLimits
        _maxItems = State(initialValue: settings.values.limits.maxItems)
        _maxMegabytes = State(initialValue: settings.values.limits.maxBytes / Self.bytesPerMegabyte)
    }

    private var draft: Limits {
        Limits(maxItems: maxItems, maxBytes: maxMegabytes * Self.bytesPerMegabyte)
    }

    private var isValid: Bool { maxItems >= 1 && maxMegabytes >= 1 }
    private var isChanged: Bool { draft != settings.values.limits }

    var body: some View {
        Form {
            Section("Shortcuts") {
                Text("No shortcuts set").foregroundStyle(.secondary)
            }
            Section {
                TextField("Keep at most (clips)", value: $maxItems, format: .number)
                TextField("Storage limit (MB)", value: $maxMegabytes, format: .number)
                HStack {
                    Button("Reset to Defaults") {
                        maxItems = Limits.default.maxItems
                        maxMegabytes = Limits.default.maxBytes / Self.bytesPerMegabyte
                    }
                    Spacer()
                    Button("Apply") {
                        Task { await apply() }
                    }
                    .disabled(!isValid || !isChanged)
                }
            } header: {
                Text("History")
            } footer: {
                Text("When either limit is reached, the least recently used clips are deleted first.")
            }
            Section("General") {
                Text("Nothing to configure yet").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 380)
    }

    private func apply() async {
        if await applyLimits(draft) { return }
        // Cancelled: show what is actually in effect.
        maxItems = settings.values.limits.maxItems
        maxMegabytes = settings.values.limits.maxBytes / Self.bytesPerMegabyte
    }
}
