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
            Section {
                ForEach(ProtectedFolder.allCases, id: \.self) { folder in
                    LabeledContent(folder.displayName) {
                        HStack(spacing: 6) {
                            Image(systemName: folderIcon(service.folderAccess.state(for: folder)))
                                .foregroundStyle(.secondary)
                            Text(folderLabel(service.folderAccess.state(for: folder)))
                        }
                    }
                }
                HStack {
                    Button(service.folderAccess.isChecking ? "Waiting for macOS…" : "Allow Access") {
                        Task { await service.folderAccess.requestAccess() }
                    }
                    .disabled(service.folderAccess.isChecking || service.folderAccess.allAllowed)
                    Spacer()
                    Button("Open Files & Folders Settings") {
                        if let url = URL(string: SystemSettingsLink.filesAndFolders) { NSWorkspace.shared.open(url) }
                    }
                    .buttonStyle(.link)
                }
            } header: {
                Text("File access")
            } footer: {
                Text("Lets CB21 show details and previews for files you copy from these folders. Until you allow a folder, CB21 won't look inside it.")
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
        .onAppear {
            launchStatus = LaunchAtLogin.status
            service.folderAccess.refreshQuietly()
        }
        .frame(width: 460, height: 780)
    }

    private func apply() async {
        if await service.applyLimits(draft) { return }
        // Cancelled: show what is actually in effect.
        maxItems = settings.values.limits.maxItems
        maxMegabytes = settings.values.limits.maxBytes / Self.bytesPerMegabyte
    }

    private func folderIcon(_ state: FolderAccessState?) -> String {
        switch state {
        case .allowed: "checkmark.circle.fill"
        case .denied: "xmark.circle"
        case .missing: "minus.circle"
        case nil: "circle.dashed"
        }
    }

    private func folderLabel(_ state: FolderAccessState?) -> String {
        switch state {
        case .allowed: "Allowed"
        case .denied: "Not allowed"
        case .missing: "Not on this Mac"
        case nil: "Not asked yet"
        }
    }
}
