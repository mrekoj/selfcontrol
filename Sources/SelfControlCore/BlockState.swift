import Foundation

public enum BlockState {
    public static func isExpired(endDate: Date, now: Date = Date()) -> Bool {
        endDate <= now
    }

    public static func isRunning(settings: Settings, now: Date = Date()) -> Bool {
        settings.blockIsRunning && !isExpired(endDate: settings.blockEndDate, now: now)
    }
}
