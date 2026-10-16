import AppKit
import SwiftUI
import CB21Core

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(service: CaptureService) {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(service: service)))
            window.title = "CB21 Settings"
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
    let service: CaptureService
    private var settings: SettingsModel { service.settings }

    @State private var launchStatus = LaunchAtLogin.status
    @State private var launchError: String?
    @State private var maxItems: Int
    @State private var maxMegabytes: Int

    private static let bytesPerMegabyte = 1024 * 1024

    init(service: CaptureService) {
        self.service = service
        let limits = service.settings.values.limits
        _maxItems = State(initialValue: limits.maxItems)
        _maxMegabytes = State(initialValue: limits.maxBytes / Self.bytesPerMegabyte)
    }

    private var draft: Limits {
        Limits(maxItems: maxItems, maxBytes: maxMegabytes * Self.bytesPerMegabyte)
    }

    private var isValid: Bool { maxItems >= 1 && maxMegabytes >= 1 }
    private var isChanged: Bool { draft != settings.values.limits }

    var body: some View {
        Form {
            Section("Shortcuts") {
                ShortcutRecorder(
                    title: "Open history",
                    shortcut: settings.values.historyShortcut,
                    onChange: { service.setHistoryShortcut($0) }
                )
                ShortcutRecorder(
                    title: "Open menu bar list",
                    shortcut: settings.values.menuShortcut,
                    onChange: { service.setMenuShortcut($0) }
                )
                ShortcutRecorder(
                    title: "Pause / resume capture",
                    shortcut: settings.values.pauseShortcut,
                    onChange: { service.setPauseShortcut($0) }
                )
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
                Toggle("Launch at login", isOn: Binding(
                    get: { launchStatus != .off },
                    set: { enabled in
                        launchError = LaunchAtLogin.set(enabled)
                        launchStatus = LaunchAtLogin.status
                    }
                ))
                if launchStatus == .needsApproval {
                    Text("Allow CB21 in System Settings > General > Login Items.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
                Button("Show Welcome…") { WelcomeWindowController.shared.show(service: service) }
            }
        }
        .formStyle(.grouped)
        .onAppear { launchStatus = LaunchAtLogin.status }
        .frame(width: 440, height: 490)
    }

    private func apply() async {
        if await service.applyLimits(draft) { return }
        // Cancelled: show what is actually in effect.
        maxItems = settings.values.limits.maxItems
        maxMegabytes = settings.values.limits.maxBytes / Self.bytesPerMegabyte
    }
}
