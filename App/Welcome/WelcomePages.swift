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
    var body: some View {
        WelcomePageLayout(
            title: "Clipboard access",
            message: "cb21 needs to read the clipboard to remember it. macOS may ask you to allow this.",
            icon: { symbol("doc.on.clipboard") },
            extra: { EmptyView() }
        )
    }
}

struct WelcomeLoginPage: View {
    var body: some View {
        WelcomePageLayout(
            title: "Start with your Mac",
            message: "Open cb21 automatically when you log in, so your history is always being kept.",
            icon: { symbol("power") },
            extra: { EmptyView() }
        )
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
