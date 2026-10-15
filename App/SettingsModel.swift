import CB21Core
import Observation

/// The user's settings, saved on every change.
@MainActor
@Observable
final class SettingsModel {
    private let persistence = SettingsPersistence()
    private(set) var values: SettingsValues

    init() {
        values = persistence.load()
    }

    func update(_ change: (inout SettingsValues) -> Void) {
        var next = values
        change(&next)
        guard next != values else { return }
        values = next
        persistence.save(next)
    }
}
