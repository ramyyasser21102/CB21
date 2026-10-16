/// Whether macOS lets CB21 read the clipboard in the background ("Paste from Other Apps", macOS 15.4 and later).
/// CB21 can't change this itself. It can only show the state and send the user to System Settings.
public enum ClipboardAccess: Sendable, Equatable, CaseIterable {
    /// macOS has never asked: the app isn't listed in System Settings yet. A first read triggers the system alert.
    case notAsked
    /// macOS asks every time, so background capture won't work reliably.
    case ask
    case alwaysAllow
    case alwaysDeny
    /// This macOS doesn't report the setting (before 15.4).
    case unknown

    public var isReady: Bool { self == .alwaysAllow }

    public var needsSystemSettings: Bool { self == .ask || self == .alwaysDeny }

    public var shouldTriggerPrompt: Bool { self == .notAsked }

    public var title: String {
        switch self {
        case .notAsked: "Not set up yet"
        case .ask: "Asks every time"
        case .alwaysAllow: "Allowed"
        case .alwaysDeny: "Blocked"
        case .unknown: "Can't be checked here"
        }
    }

    public var explanation: String {
        switch self {
        case .notAsked:
            "macOS is about to ask. Choose Always Allow so CB21 can keep your history."
        case .ask:
            "CB21 can't capture reliably while macOS asks for every copy. In System Settings, choose Always Allow."
        case .alwaysAllow:
            "CB21 can read the clipboard. You're set."
        case .alwaysDeny:
            "CB21 can't capture anything right now. In System Settings, choose Always Allow."
        case .unknown:
            "This version of macOS doesn't report clipboard access. If copies don't show up in CB21, check Privacy & Security in System Settings."
        }
    }
}

/// Where to send the user. `Privacy_Pasteboard` is the "Paste from Other Apps" pane.
public enum SystemSettingsLink {
    public static let pasteboard = "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard"
    public static let privacy = "x-apple.systempreferences:com.apple.preference.security?Privacy"
    public static let filesAndFolders = "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
    public static let loginItems = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
}
