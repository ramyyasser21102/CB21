import AppKit
import SwiftUI
import CB21Core

/// The app image. It fades in while growing slightly to full size; with Reduce Motion it only fades.
struct WelcomeLogo: View {
    @State private var settled = false
    @Environment(\.welcomeReady) private var ready
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("WelcomeLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 120)
            .scaleEffect(reduceMotion || settled ? 1 : 0.92)
            .opacity(settled ? 1 : 0)
            .accessibilityHidden(true)
            .onAppear { if ready { settle() } }
            .onChange(of: ready) { _, nowReady in if nowReady { settle() } }
    }

    private func settle() {
        guard !settled else { return }
        withAnimation(.easeOut(duration: reduceMotion ? 0.25 : 1.4)) { settled = true }
    }
}

/// The layout every page shares: a symbol or the logo, a title, and some text.
struct WelcomePageLayout<Icon: View, Extra: View>: View {
    let title: String
    let message: String
    @ViewBuilder let icon: Icon
    @ViewBuilder let extra: Extra

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            icon.frame(height: 120)
            Text(title)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.5)
                .foregroundStyle(.white)
                .welcomeAppear(delay: 0.15)
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(WelcomeStyle.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)
                .welcomeAppear(delay: 0.3)
            extra.welcomeAppear(delay: 0.45)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

@MainActor
private func symbol(_ name: String) -> some View {
    Image(systemName: name)
        .font(.system(size: 64, weight: .light))
        .foregroundStyle(.white)
        .accessibilityHidden(true)
        .welcomeAppear(delay: 0)
}

struct WelcomeIntroPage: View {
    var body: some View {
        WelcomePageLayout(
            title: "CB21",
            message: "Everything you copy, remembered.\nPaste anything again without copying it twice.",
            icon: { WelcomeLogo() },
            extra: { EmptyView() }
        )
    }
}

struct WelcomeClipboardPage: View {
    let service: CaptureService
    @State private var access: ClipboardAccess
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(service: CaptureService) {
        self.service = service
        _access = State(initialValue: service.systemPasteboard.accessStatus)
    }

    var body: some View {
        WelcomePageLayout(
            title: "Clipboard access",
            message: "CB21 needs to read the clipboard to remember it. macOS asks you to allow this once.",
            icon: { symbol("doc.on.clipboard") },
            extra: { status }
        )
        // While this page is showing: trigger the system prompt if it never appeared, then keep the status
        // live, because the user may change it in System Settings and come back.
        .task {
            if access.shouldTriggerPrompt {
                try? await Task.sleep(for: .milliseconds(900))
                let pasteboard = service.systemPasteboard
                await Task.detached { pasteboard.triggerAccessPrompt() }.value
            }
            while !Task.isCancelled {
                let current = service.systemPasteboard.accessStatus
                if current != access {
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.7)) {
                        access = current
                    }
                }
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
    }

    private var status: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: access.isReady ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 26))
                    .foregroundStyle(access.isReady ? .white : WelcomeStyle.secondary)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    .symbolEffect(.bounce, options: reduceMotion ? .nonRepeating.speed(0) : .nonRepeating, value: access.isReady)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(access.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text(access.explanation)
                        .font(.system(size: 14)).foregroundStyle(WelcomeStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: 420)
            .background(RoundedRectangle(cornerRadius: 12).stroke(WelcomeStyle.faint, lineWidth: 1))
            .accessibilityElement(children: .combine)

            if access.needsSystemSettings {
                Button("Open System Settings") {
                    if let url = URL(string: SystemSettingsLink.pasteboard) { NSWorkspace.shared.open(url) }
                }
                .buttonStyle(WelcomeOutlineButtonStyle())
                .transition(.opacity)
            }
        }
    }
}

struct WelcomeFilesPage: View {
    let service: CaptureService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var access: FolderAccessModel { service.folderAccess }

    var body: some View {
        WelcomePageLayout(
            title: "Your files",
            message: "CB21 shows details and previews for files you copy. macOS asks before an app may look inside Desktop, Documents and Downloads, so it's best to answer now.",
            icon: { symbol("folder") },
            extra: {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        ForEach(Array(ProtectedFolder.allCases.enumerated()), id: \.element) { index, folder in
                            if index > 0 { Divider().overlay(WelcomeStyle.faint) }
                            row(folder)
                        }
                    }
                    .frame(maxWidth: 420)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(WelcomeStyle.faint, lineWidth: 1))

                    HStack(spacing: 12) {
                        if !access.allAllowed {
                            Button(access.isChecking ? "Waiting for macOS…" : "Allow Access") {
                                Task { await access.requestAccess() }
                            }
                            .buttonStyle(WelcomeOutlineButtonStyle())
                            .disabled(access.isChecking)
                        }
                        if ProtectedFolder.allCases.contains(where: { access.state(for: $0) == .denied }) {
                            Button("Open System Settings") {
                                if let url = URL(string: SystemSettingsLink.filesAndFolders) { NSWorkspace.shared.open(url) }
                            }
                            .buttonStyle(WelcomeQuietButtonStyle())
                        }
                    }
                    Text("You can skip this. Files in these folders just won't show details until you allow them.")
                        .font(.system(size: 13)).foregroundStyle(WelcomeStyle.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 400)
                }
            }
        )
    }

    private func row(_ folder: ProtectedFolder) -> some View {
        let state = access.state(for: folder)
        return HStack(spacing: 12) {
            Image(systemName: icon(for: state))
                .font(.system(size: 18))
                .foregroundStyle(state == .allowed ? Color.white : WelcomeStyle.secondary)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                .symbolEffect(.bounce, options: reduceMotion ? .nonRepeating.speed(0) : .nonRepeating, value: state == .allowed)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(folder.displayName).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
            Spacer()
            Text(label(for: state)).font(.system(size: 14)).foregroundStyle(WelcomeStyle.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func icon(for state: FolderAccessState?) -> String {
        switch state {
        case .allowed: "checkmark.circle.fill"
        case .denied: "xmark.circle"
        case .missing: "minus.circle"
        case nil: "circle.dashed"
        }
    }

    private func label(for state: FolderAccessState?) -> String {
        switch state {
        case .allowed: "Allowed"
        case .denied: "Not allowed"
        case .missing: "Not on this Mac"
        case nil: "Not asked yet"
        }
    }
}

struct WelcomeLoginPage: View {
    @State private var status = LaunchAtLogin.status
    @State private var error: String?

    var body: some View {
        WelcomePageLayout(
            title: "Start with your Mac",
            message: "Open CB21 automatically when you log in, so your history is always being kept.",
            icon: { symbol("power") },
            extra: {
                VStack(spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { status != .off },
                        set: { enabled in
                            error = LaunchAtLogin.set(enabled)
                            status = LaunchAtLogin.status
                        }
                    )) {
                        Text("Open CB21 at login").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    }
                    .toggleStyle(.switch)
                    .tint(.white)
                    .padding(16)
                    .frame(maxWidth: 420)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(WelcomeStyle.faint, lineWidth: 1))

                    if status == .needsApproval {
                        Text("macOS needs you to allow CB21 once in Login Items.")
                            .font(.system(size: 14)).foregroundStyle(WelcomeStyle.secondary)
                        Button("Open Login Items") {
                            if let url = URL(string: SystemSettingsLink.loginItems) { NSWorkspace.shared.open(url) }
                        }
                        .buttonStyle(WelcomeOutlineButtonStyle())
                    }
                    if let error {
                        Text(error).font(.system(size: 13)).foregroundStyle(WelcomeStyle.secondary)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: status)
            }
        )
        // The user may approve it in System Settings and come back to this page.
        .task {
            while !Task.isCancelled {
                status = LaunchAtLogin.status
                try? await Task.sleep(for: .milliseconds(800))
            }
        }
    }
}

struct WelcomeShortcutsPage: View {
    let service: CaptureService

    var body: some View {
        let values = service.settings.values
        WelcomePageLayout(
            title: "Shortcuts",
            message: "Open your history, or the menu bar list, from any app. All three are optional.",
            icon: { symbol("keyboard") },
            extra: {
                VStack(spacing: 14) {
                    ShortcutRecorder(title: "Open history", dark: true, shortcut: values.historyShortcut,
                                     onChange: { service.setHistoryShortcut($0) })
                    Divider().overlay(WelcomeStyle.faint)
                    ShortcutRecorder(title: "Open menu bar list", dark: true, shortcut: values.menuShortcut,
                                     onChange: { service.setMenuShortcut($0) })
                    Divider().overlay(WelcomeStyle.faint)
                    ShortcutRecorder(title: "Pause / resume capture", dark: true, shortcut: values.pauseShortcut,
                                     onChange: { service.setPauseShortcut($0) })
                }
                .padding(16)
                .frame(maxWidth: 420)
                .background(RoundedRectangle(cornerRadius: 12).stroke(WelcomeStyle.faint, lineWidth: 1))
            }
        )
    }
}

struct WelcomePrivacyPage: View {
    private let points: [(String, String, String)] = [
        ("wifi.slash", "No network", "CB21 never connects to the internet."),
        ("internaldrive", "Stored on your Mac", "History stays on this Mac and is not encrypted."),
        ("pause.circle", "You stay in control", "Password-manager copies are skipped, and Pause covers the rest."),
    ]

    var body: some View {
        WelcomePageLayout(
            title: "Private by design",
            message: "",
            icon: { symbol("lock.shield") },
            extra: {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(points, id: \.1) { point in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: point.0)
                                .font(.system(size: 20, weight: .regular))
                                .frame(width: 28)
                                .foregroundStyle(.white)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(point.1).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                                Text(point.2).font(.system(size: 14)).foregroundStyle(WelcomeStyle.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: 400, alignment: .leading)
            }
        )
    }
}
