import Foundation

public struct SelfControlVersion {
    public static let current = "0.1.0"
}

public struct BlocklistEntry: Hashable, Codable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
