import ServiceManagement

/// Launch at login through `SMAppService`. The system keeps the setting, so it is read, never saved by cb21.
enum LaunchAtLogin {
    enum Status: Equatable {
        case off
        case on
        /// Registered, but the user still has to allow it in System Settings > General > Login Items.
        case needsApproval
    }

    static var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled: .on
        case .requiresApproval: .needsApproval
        default: .off
        }
    }

    /// Returns an error message, or nil on success.
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return "Couldn't change launch at login: \(error.localizedDescription)"
        }
    }
}
