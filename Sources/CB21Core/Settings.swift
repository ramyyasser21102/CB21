import Foundation

/// Everything the user can configure. Each step adds its own fields with a default,
/// so settings saved by an older version still load.
public struct SettingsValues: Sendable, Equatable, Codable {
    public var limits: Limits = .default

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        limits = try c.decodeIfPresent(Limits.self, forKey: .limits) ?? .default
    }
}

/// Saves `SettingsValues` as one JSON value in UserDefaults.
public struct SettingsPersistence: @unchecked Sendable {
    public static let key = "cb21.settings"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SettingsValues {
        guard let data = defaults.data(forKey: Self.key),
              let values = try? JSONDecoder().decode(SettingsValues.self, from: data) else {
            return SettingsValues()
        }
        return values
    }

    public func save(_ values: SettingsValues) {
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
