import AppKit
import SwiftUI
import CB21Core

/// The first-run Welcome window: fixed size, black, always dark whatever the system theme.
@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    static let shared = WelcomeWindowController()

    private var window: NSWindow?
    private weak var service: CaptureService?

    /// Opens the window on first run only.
    func showIfFirstRun(service: CaptureService) {
        guard !service.settings.values.welcomeCompleted else { return }
        show(service: service)
    }

    func show(service: CaptureService) {
        self.service = service
        if window == nil {
            let size = NSSize(width: 560, height: 640)
            let hosting = NSHostingView(rootView: WelcomeView(service: service, finish: { [weak self] in
                self?.window?.close()
            }))
            // The window decides the size. Letting the hosting view resize it is what can make the first frames jump.
            hosting.sizingOptions = []
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.contentView = hosting
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .black
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.setContentSize(size)
            window.contentMinSize = size
            window.contentMaxSize = size
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Closing at any step counts as done, so the window doesn't come back by itself.
    func windowWillClose(_ notification: Notification) {
        service?.settings.update { $0.welcomeCompleted = true }
        // Reopening builds a fresh window, so the pages and animations start from the beginning.
        window = nil
    }
}
