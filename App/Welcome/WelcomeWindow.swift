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
            let hosting = NSHostingController(rootView: WelcomeView(service: service, finish: { [weak self] in
                self?.window?.close()
            }))
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .black
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 560, height: 640))
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
        // A new page flow and animation each time it is reopened.
        window?.contentViewController = nil
        window = nil
    }
}
