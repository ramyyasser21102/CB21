import SwiftUI

/// Black and white only, in the system font.
enum WelcomeStyle {
    static let secondary = Color.white.opacity(0.6)
    static let faint = Color.white.opacity(0.25)
}

/// A white capsule with black text.
struct WelcomePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Capsule().fill(.white))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A white outline with white text, for actions that aren't the main one.
struct WelcomeOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .overlay(Capsule().stroke(.white.opacity(configuration.isPressed ? 0.4 : 0.8), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet text button for Back and Skip.
struct WelcomeQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundStyle(configuration.isPressed ? WelcomeStyle.faint : WelcomeStyle.secondary)
    }
}

/// False for the first moments after the Welcome window opens. Entrance animations wait for it, so they never
/// start while SwiftUI is still doing its first layout (which can make views fly in from the top-left corner).
private struct WelcomeReadyKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var welcomeReady: Bool {
        get { self[WelcomeReadyKey.self] }
        set { self[WelcomeReadyKey.self] = newValue }
    }
}

/// Fades and lifts content in, one after another. With Reduce Motion it only fades.
struct WelcomeAppear: ViewModifier {
    let delay: Double
    @State private var shown = false
    @Environment(\.welcomeReady) private var ready
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear { if ready { reveal() } }
            .onChange(of: ready) { _, nowReady in if nowReady { reveal() } }
    }

    private func reveal() {
        guard !shown else { return }
        withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.55).delay(reduceMotion ? 0 : delay)) {
            shown = true
        }
    }
}

extension View {
    func welcomeAppear(delay: Double = 0) -> some View {
        modifier(WelcomeAppear(delay: delay))
    }
}
