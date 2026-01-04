import Foundation
import SelfControlCore

final class DaemonService: NSObject, NSXPCListenerDelegate, DaemonXPCProtocol {
    private let listener: NSXPCListener

    init(machServiceName: String = DaemonConstants.machServiceName) {
        self.listener = NSXPCListener(machServiceName: machServiceName)
        super.init()
        listener.delegate = self
    }

    func start() {
        NSLog("selfcontrold: starting XPC listener for %@", DaemonConstants.machServiceName)
        listener.resume()
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: DaemonXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // MARK: - DaemonXPCProtocol

    func startBlock(blocklist: [String], isAllowlist: Bool, endDate: Date, settings: BlockSettings, authorization: Data?, withReply reply: @escaping (NSError?) -> Void) {
        NSLog("selfcontrold: startBlock called (blocklist=%d)", blocklist.count)
        reply(nil)
    }

    func updateBlocklist(_ newBlocklist: [String], authorization: Data?, withReply reply: @escaping (NSError?) -> Void) {
        NSLog("selfcontrold: updateBlocklist called (blocklist=%d)", newBlocklist.count)
        reply(nil)
    }

    func updateBlockEndDate(_ newEndDate: Date, authorization: Data?, withReply reply: @escaping (NSError?) -> Void) {
        NSLog("selfcontrold: updateBlockEndDate called")
        reply(nil)
    }

    func getVersion(withReply reply: @escaping (String) -> Void) {
        reply(SelfControlVersion.current)
    }
}
