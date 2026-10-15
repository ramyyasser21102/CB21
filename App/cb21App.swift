import SwiftUI
import CB21Core

@main
struct CB21App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // The menu bar icon is an AppKit status item (see StatusMenuController), so the app has no scene of its own.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let service = CaptureService.shared
        service.start()
        let statusMenu = StatusMenuController(service: service)
        service.openMenu = { [weak statusMenu] in statusMenu?.openMenu() }
        service.shouldOpenMenu = { [weak statusMenu] in statusMenu?.shouldOpenFromShortcut() ?? false }
        self.statusMenu = statusMenu
    }
}
