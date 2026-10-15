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

@Test func historyShortcutIsUnboundByDefaultAndPersists() {
    #expect(SettingsValues().historyShortcut == nil)
    let defaults = freshDefaults()
    var values = SettingsValues()
    values.historyShortcut = Shortcut(keyCode: 9, modifiers: [.command, .shift])
    SettingsPersistence(defaults: defaults).save(values)
    #expect(SettingsPersistence(defaults: defaults).load().historyShortcut == values.historyShortcut)
}

@Test func settingsSavedBeforeShortcutsExistedStillLoad() {
    let defaults = freshDefaults()
    defaults.set(Data(#"{"limits":{"maxItems":10,"maxBytes":2048}}"#.utf8), forKey: SettingsPersistence.key)
    let loaded = SettingsPersistence(defaults: defaults).load()
    #expect(loaded.limits == Limits(maxItems: 10, maxBytes: 2048))
    #expect(loaded.historyShortcut == nil)
}

@Test func pauseShortcutIsUnboundByDefaultAndPersists() {
    #expect(SettingsValues().pauseShortcut == nil)
    let defaults = freshDefaults()
    var values = SettingsValues()
    values.pauseShortcut = Shortcut(keyCode: 35, modifiers: [.control, .option])
    SettingsPersistence(defaults: defaults).save(values)
    #expect(SettingsPersistence(defaults: defaults).load().pauseShortcut == values.pauseShortcut)
}

@Test func menuShortcutIsUnboundByDefaultAndPersists() {
    #expect(SettingsValues().menuShortcut == nil)
    let defaults = freshDefaults()
    var values = SettingsValues()
    values.menuShortcut = Shortcut(keyCode: 46, modifiers: [.control, .option])
    SettingsPersistence(defaults: defaults).save(values)
    #expect(SettingsPersistence(defaults: defaults).load().menuShortcut == values.menuShortcut)
}
