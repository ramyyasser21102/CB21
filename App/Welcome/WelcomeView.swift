import SwiftUI
import CB21Core

struct WelcomeView: View {
    let service: CaptureService
    /// Called once the flow is finished, so the window can close.
    let finish: () -> Void

    @State private var flow = WelcomeFlow()
    /// False until the first layout has settled; see `WelcomeReadyKey`.
    @State private var ready = false
    /// The edge new pages slide in from. Set before each move so the transition knows which way to go.
    @State private var entering: Edge = .trailing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    page(flow.page)
                        .id(flow.page)
                        .transition(pageTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                footer
            }
            skipButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .environment(\.welcomeReady, ready)
        // No implicit animation in the first moments, whatever else is happening as the window appears.
        .transaction { transaction in
            if !ready { transaction.animation = nil }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(180))
            ready = true
        }
        .onChange(of: flow.isFinished) { _, done in
            if done { finish() }
        }
    }

    @ViewBuilder
    private func page(_ page: WelcomeFlow.Page) -> some View {
        switch page {
        case .welcome: WelcomeIntroPage()
        case .clipboard: WelcomeClipboardPage(service: service)
        case .files: WelcomeFilesPage(service: service)
        case .login: WelcomeLoginPage()
        case .shortcuts: WelcomeShortcutsPage(service: service)
        case .privacy: WelcomePrivacyPage()
        }
    }

    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let leaving: Edge = entering == .trailing ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: entering).combined(with: .opacity),
            removal: .move(edge: leaving).combined(with: .opacity)
        )
    }

    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.55, dampingFraction: 0.86)
    }

    private var footer: some View {
        HStack {
            Button("Back") { move(forward: false) }
                .buttonStyle(WelcomeQuietButtonStyle())
                .keyboardShortcut(.leftArrow, modifiers: [])
                .opacity(flow.isFirstPage ? 0 : 1)
                .disabled(flow.isFirstPage)
                .frame(width: 90, alignment: .leading)
            Spacer()
            progressDots
            Spacer()
            Button(primaryTitle) { move(forward: true) }
                .buttonStyle(WelcomePrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .frame(minWidth: 90, alignment: .trailing)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .padding(.top, 8)
    }

    private var primaryTitle: String {
        if flow.isFirstPage { return "Get started" }
        return flow.isLastPage ? "Start using CB21" : "Continue"
    }

    /// The current page's dot stretches into a bar; pages already visited are brighter.
    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(WelcomeFlow.Page.allCases, id: \.self) { dot in
                Capsule()
                    .fill(dot.rawValue <= flow.page.rawValue ? Color.white : WelcomeStyle.faint)
                    .frame(width: dot == flow.page ? 22 : 6, height: 6)
            }
        }
        .animation(animation, value: flow.page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(flow.pageNumber) of \(flow.pageCount)")
    }

    /// The pages in the middle can be skipped; the first and last are just read.
    @ViewBuilder
    private var skipButton: some View {
        if !flow.isFirstPage && !flow.isLastPage {
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") { skip() }
                        .buttonStyle(WelcomeQuietButtonStyle())
                        .padding(.top, 14)
                        .padding(.trailing, 24)
                }
                Spacer()
            }
            .transition(.opacity)
        }
    }

    private func move(forward: Bool) {
        entering = forward ? .trailing : .leading
        withAnimation(animation) {
            if forward { flow.next() } else { flow.back() }
        }
    }

    private func skip() {
        entering = .trailing
        withAnimation(animation) { flow.skipPage() }
    }
}
