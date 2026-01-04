import Foundation

public enum SelfControlErrorCode: Int {
    case unknown = 1
    case blockAlreadyRunning = 301
    case emptyBlocklist = 302
    case blockNotRunning = 304
    case updateNotAllowedForAllowlist = 305
    case endDateEarlierThanCurrent = 308
    case endDateTooFarInFuture = 309
}

public enum SelfControlError {
    public static let domain = "com.skynet.selfcontrol.error"

    public static func make(_ code: SelfControlErrorCode, description: String? = nil) -> NSError {
        var info: [String: Any] = [:]
        if let description {
            info[NSLocalizedDescriptionKey] = description
        }
        return NSError(domain: domain, code: code.rawValue, userInfo: info)
    }
}
