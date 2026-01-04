import Foundation

public enum BundleIdentifiers {
    public static let app = "com.skynet.selfcontrol"
    public static let daemon = "com.skynet.selfcontrold"
    public static let cli = "com.skynet.selfcontrol-cli"
}

public enum DaemonConstants {
    public static let machServiceName = BundleIdentifiers.daemon
}

@objc public protocol DaemonXPCProtocol {
    func startBlock(blocklist: [String],
                    isAllowlist: Bool,
                    endDate: Date,
                    settings: BlockSettings,
                    authorization: Data?,
                    withReply reply: @escaping (NSError?) -> Void)

    func updateBlocklist(_ newBlocklist: [String],
                         authorization: Data?,
                         withReply reply: @escaping (NSError?) -> Void)

    func updateBlockEndDate(_ newEndDate: Date,
                            authorization: Data?,
                            withReply reply: @escaping (NSError?) -> Void)

    func clearBlock(reason: String?,
                    authorization: Data?,
                    withReply reply: @escaping (NSError?) -> Void)

    func getVersion(withReply reply: @escaping (String) -> Void)
}

public final class BlockSettings: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }

    public let evaluateCommonSubdomains: Bool
    public let includeLinkedDomains: Bool
    public let blockSoundShouldPlay: Bool
    public let blockSound: Int
    public let clearCaches: Bool
    public let allowLocalNetworks: Bool
    public let enableErrorReporting: Bool

    public init(evaluateCommonSubdomains: Bool,
                includeLinkedDomains: Bool,
                blockSoundShouldPlay: Bool,
                blockSound: Int,
                clearCaches: Bool,
                allowLocalNetworks: Bool,
                enableErrorReporting: Bool) {
        self.evaluateCommonSubdomains = evaluateCommonSubdomains
        self.includeLinkedDomains = includeLinkedDomains
        self.blockSoundShouldPlay = blockSoundShouldPlay
        self.blockSound = blockSound
        self.clearCaches = clearCaches
        self.allowLocalNetworks = allowLocalNetworks
        self.enableErrorReporting = enableErrorReporting
    }

    public convenience init(from settings: Settings) {
        self.init(
            evaluateCommonSubdomains: settings.evaluateCommonSubdomains,
            includeLinkedDomains: settings.includeLinkedDomains,
            blockSoundShouldPlay: settings.blockSoundShouldPlay,
            blockSound: settings.blockSound,
            clearCaches: settings.clearCaches,
            allowLocalNetworks: settings.allowLocalNetworks,
            enableErrorReporting: settings.enableErrorReporting
        )
    }

    public func encode(with coder: NSCoder) {
        coder.encode(evaluateCommonSubdomains, forKey: "evaluateCommonSubdomains")
        coder.encode(includeLinkedDomains, forKey: "includeLinkedDomains")
        coder.encode(blockSoundShouldPlay, forKey: "blockSoundShouldPlay")
        coder.encode(blockSound, forKey: "blockSound")
        coder.encode(clearCaches, forKey: "clearCaches")
        coder.encode(allowLocalNetworks, forKey: "allowLocalNetworks")
        coder.encode(enableErrorReporting, forKey: "enableErrorReporting")
    }

    public required init?(coder: NSCoder) {
        self.evaluateCommonSubdomains = coder.decodeBool(forKey: "evaluateCommonSubdomains")
        self.includeLinkedDomains = coder.decodeBool(forKey: "includeLinkedDomains")
        self.blockSoundShouldPlay = coder.decodeBool(forKey: "blockSoundShouldPlay")
        self.blockSound = coder.decodeInteger(forKey: "blockSound")
        self.clearCaches = coder.decodeBool(forKey: "clearCaches")
        self.allowLocalNetworks = coder.decodeBool(forKey: "allowLocalNetworks")
        self.enableErrorReporting = coder.decodeBool(forKey: "enableErrorReporting")
    }
}

public final class DaemonClient {
    public static let shared = DaemonClient()

    private var connection: NSXPCConnection?

    public func connect() -> NSXPCConnection {
        if let existing = connection {
            return existing
        }

        let conn = NSXPCConnection(machServiceName: DaemonConstants.machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: DaemonXPCProtocol.self)
        conn.resume()
        connection = conn
        return conn
    }

    public func remoteProxy() -> DaemonXPCProtocol? {
        let conn = connect()
        return conn.remoteObjectProxy as? DaemonXPCProtocol
    }

    public func invalidate() {
        connection?.invalidate()
        connection = nil
    }
}
