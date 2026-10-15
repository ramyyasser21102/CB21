import Foundation
import Testing
@testable import CB21Core

private func freshDefaults() -> UserDefaults {
    let name = "cb21-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@Test func missingSettingsLoadAsDefaults() {
    let persistence = SettingsPersistence(defaults: freshDefaults())
    #expect(persistence.load() == SettingsValues())
    #expect(persistence.load().limits == .default)
}

@Test func savedSettingsComeBackAfterReloading() {
    let defaults = freshDefaults()
    var values = SettingsValues()
    values.limits = Limits(maxItems: 25, maxBytes: 5_000_000)
    SettingsPersistence(defaults: defaults).save(values)
    #expect(SettingsPersistence(defaults: defaults).load() == values)
}

@Test func unreadableStoredSettingsFallBackToDefaults() {
    let defaults = freshDefaults()
    defaults.set(Data("not json".utf8), forKey: SettingsPersistence.key)
    #expect(SettingsPersistence(defaults: defaults).load() == SettingsValues())
}
