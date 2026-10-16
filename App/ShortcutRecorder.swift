import AppKit
import SwiftUI
import CB21Core

/// Records a key combination. Escape cancels, and the result is checked before it is accepted.
struct ShortcutRecorder: View {
    let title: String
    /// White on black, for the Welcome window. Settings uses the system look.
    var dark = false
    let shortcut: Shortcut?
    /// Returns an error message to show, or nil when the shortcut was accepted.
    let onChange: (Shortcut?) -> String?

    @State private var isRecording = false
    @State private var message: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if dark {
                HStack {
                    Text(title).font(.system(size: 15)).foregroundStyle(.white)
                    Spacer()
                    controls
                }
            } else {
                LabeledContent(title) { controls }
            }
            if let message {
                if dark {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12)).foregroundStyle(WelcomeStyle.secondary)
                } else {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .onDisappear { stop() }
    }

    private var controls: some View {
        HStack {
            if dark {
                Button(isRecording ? "Press shortcut…" : (shortcut?.label ?? "Not set")) {
                    isRecording ? stop() : start()
                }
                .buttonStyle(WelcomeOutlineButtonStyle())
                if shortcut != nil {
                    Button("Reset") { message = onChange(nil) }
                        .buttonStyle(WelcomeQuietButtonStyle())
                }
            } else {
                Button(isRecording ? "Press shortcut…" : (shortcut?.label ?? "Not set")) {
                    isRecording ? stop() : start()
                }
                if shortcut != nil {
                    Button("Reset") { message = onChange(nil) }
                }
            }
        }
    }

    private func start() {
        message = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                stop()
                return nil
            }
            var modifiers: ShortcutModifiers = []
            if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
            if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
            if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
            if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
            let recorded = Shortcut(keyCode: event.keyCode, modifiers: modifiers)
            message = onChange(recorded)
            stop()
            return nil
        }
    }

    private func stop() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
