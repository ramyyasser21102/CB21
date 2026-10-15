import SwiftUI
import CB21Core

@main
struct CB21App: App {
    var body: some Scene {
        MenuBarExtra("cb21", systemImage: "doc.on.clipboard") {
            Button("Quit cb21") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
