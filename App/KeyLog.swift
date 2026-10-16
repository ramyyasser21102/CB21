import AppKit

/// A switch for finding out how a real key reaches the open menu, which can't be tested without pressing keys.
/// Off by default. Turn it on with: defaults write com.ramyyasser.cb21 debugKeys -bool true
/// The log is ~/Library/Logs/CB21-keys.log. It only records ⌘+key presses and which handler saw them, never typed text.
enum KeyLog {
    static var enabled: Bool { UserDefaults.standard.bool(forKey: "debugKeys") }

    static func write(_ line: @autoclosure () -> String) {
        guard enabled else { return }
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/CB21-keys.log")
        let data = Data("\(ISO8601DateFormatter().string(from: Date())) \(line())\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    /// For key equivalents only: the digit pressed (or "other") and the modifiers, nothing else.
    static func describe(_ event: NSEvent) -> String {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers.flatMap { $0.count == 1 && $0.first!.isNumber ? $0 : "other" } ?? "none"
        return "key=\(key) command=\(flags.contains(.command)) option=\(flags.contains(.option)) shift=\(flags.contains(.shift)) control=\(flags.contains(.control))"
    }
}
