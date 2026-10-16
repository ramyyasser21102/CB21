import AppKit
import SwiftUI
import CB21Core

/// The cb21 glyph. It wipes in from the top while it fades and settles; with Reduce Motion it only fades.
struct WelcomeLogo: View {
    @State private var reveal: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("WelcomeLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 120)
            .mask(alignment: .top) {
                Rectangle().scaleEffect(y: reduceMotion ? 1 : reveal, anchor: .top)
            }
            .scaleEffect(reduceMotion ? 1 : 0.88 + 0.12 * reveal)
            .opacity(Double(min(1, reveal * 1.6)))
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? 0.25 : 1.1)) { reveal = 1 }
            }
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
            title: "cb21",
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
            message: "cb21 needs to read the clipboard to remember it. macOS asks you to allow this once.",
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

struct WelcomeLoginPage: View {
    @State private var status = LaunchAtLogin.status
    @State private var error: String?

    var body: some View {
        WelcomePageLayout(
            title: "Start with your Mac",
            message: "Open cb21 automatically when you log in, so your history is always being kept.",
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
                        Text("Open cb21 at login").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    }
                    .toggleStyle(.switch)
                    .tint(.white)
                    .padding(16)
                    .frame(maxWidth: 420)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(WelcomeStyle.faint, lineWidth: 1))

                    if status == .needsApproval {
                        Text("macOS needs you to allow cb21 once in Login Items.")
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
    var body: some View {
        WelcomePageLayout(
            title: "Shortcuts",
            message: "Open your history, or the menu bar list, from any app. Both are optional.",
            icon: { symbol("keyboard") },
            extra: { EmptyView() }
        )
    }
}

struct WelcomePrivacyPage: View {
    private let points: [(String, String, String)] = [
        ("wifi.slash", "No network", "cb21 never connects to the internet."),
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
