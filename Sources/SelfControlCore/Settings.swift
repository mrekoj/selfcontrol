import Foundation

public struct Settings: Codable, Equatable {
    public var blockEndDate: Date
    public var activeBlocklist: [String]
    public var activeBlockAsWhitelist: Bool

    public var blockIsRunning: Bool
    public var tamperingDetected: Bool

    public var evaluateCommonSubdomains: Bool
    public var includeLinkedDomains: Bool
    public var blockSoundShouldPlay: Bool
    public var blockSound: Int
    public var clearCaches: Bool
    public var allowLocalNetworks: Bool
    public var enableErrorReporting: Bool

    public var settingsVersionNumber: Int
    public var lastSettingsUpdate: Date

    public static let defaults = Settings(
        blockEndDate: .distantPast,
        activeBlocklist: [],
        activeBlockAsWhitelist: false,
        blockIsRunning: false,
        tamperingDetected: false,
        evaluateCommonSubdomains: true,
        includeLinkedDomains: true,
        blockSoundShouldPlay: false,
        blockSound: 5,
        clearCaches: true,
        allowLocalNetworks: true,
        enableErrorReporting: true,
        settingsVersionNumber: 0,
        lastSettingsUpdate: .distantPast
    )

    public func updatedForWrite(date: Date = Date()) -> Settings {
        var copy = self
        copy.settingsVersionNumber += 1
        copy.lastSettingsUpdate = date
        return copy
    }
}

public final class SettingsStore {
    public let url: URL
    private let encoder: PropertyListEncoder
    private let decoder: PropertyListDecoder

    public init(url: URL) {
        self.url = url
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        self.encoder = encoder
        self.decoder = PropertyListDecoder()
    }

    public func load() throws -> Settings {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return Settings.defaults
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(Settings.self, from: data)
    }

    public func save(_ settings: Settings, date: Date = Date()) throws {
        let updated = settings.updatedForWrite(date: date)
        let data = try encoder.encode(updated)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }
}

public enum SettingsPaths {
    public static func fileName(serialNumber: String) -> String {
        let seed = "SelfControlUserPreferences" + serialNumber
        return ".\(Hashing.sha1(seed)).plist"
    }

    public static func defaultURL(serialNumber: String) -> URL {
        URL(fileURLWithPath: "/usr/local/etc", isDirectory: true)
            .appendingPathComponent(fileName(serialNumber: serialNumber))
    }
}
