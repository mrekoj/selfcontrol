import Foundation

public enum EmergencyUnlockLogger {
    public static let logPath = "/var/log/selfcontrol-unlock.log"

    public static func log(reason: String?, cleared: Bool) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let message = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let reasonText = (message?.isEmpty == false) ? message! : "(no reason provided)"
        let status = cleared ? "cleared" : "attempted"
        let line = "\(timestamp) | \(status) | \(reasonText)\n"
        append(line)
    }

    private static func append(_ line: String) {
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let handle = FileHandle(forWritingAtPath: logPath) {
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                    return
                }
            }
            try? data.write(to: URL(fileURLWithPath: logPath), options: [.atomic])
        }
    }
}
