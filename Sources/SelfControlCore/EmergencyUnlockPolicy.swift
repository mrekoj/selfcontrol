import Foundation

public struct EmergencyUnlockPolicy {
    public let cooldownMinutes: Int
    public let maxPerDay: Int

    public init(cooldownMinutes: Int = 15, maxPerDay: Int = 1) {
        self.cooldownMinutes = cooldownMinutes
        self.maxPerDay = maxPerDay
    }

    public func canUnlock(history: [EmergencyUnlockRecord], now: Date = Date()) -> Bool {
        let sinceCooldown = now.addingTimeInterval(TimeInterval(-cooldownMinutes * 60))
        if history.contains(where: { $0.date > sinceCooldown }) {
            return false
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let todaysCount = history.filter { $0.date >= today }.count
        return todaysCount < maxPerDay
    }
}

public struct EmergencyUnlockRecord: Codable {
    public let date: Date
    public let reason: String?

    public init(date: Date, reason: String?) {
        self.date = date
        self.reason = reason
    }
}

public final class EmergencyUnlockStore {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(url: URL) {
        self.url = url
    }

    public func load() -> [EmergencyUnlockRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([EmergencyUnlockRecord].self, from: data)) ?? []
    }

    public func append(_ record: EmergencyUnlockRecord) {
        var history = load()
        history.append(record)
        let data = (try? encoder.encode(history)) ?? Data()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic])
    }
}
