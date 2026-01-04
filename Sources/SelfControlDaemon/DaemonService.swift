import Foundation
import SelfControlCore

final class DaemonService: NSObject, NSXPCListenerDelegate, DaemonXPCProtocol {
    private let listener: NSXPCListener
    private let settingsStore: SettingsStore

    init(machServiceName: String = DaemonConstants.machServiceName) {
        self.listener = NSXPCListener(machServiceName: machServiceName)
        let serial = SystemInfo.serialNumber() ?? "UNKNOWN"
        let settingsURL = SettingsPaths.defaultURL(serialNumber: serial)
        self.settingsStore = SettingsStore(url: settingsURL)
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
        do {
            var current = try settingsStore.load()
            if BlockState.isRunning(settings: current) {
                reply(SelfControlError.make(.blockAlreadyRunning, description: "Block already running"))
                return
            }
            if (blocklist.isEmpty && !isAllowlist) || BlockState.isExpired(endDate: endDate) {
                reply(SelfControlError.make(.emptyBlocklist, description: "Blocklist empty or end date in past"))
                return
            }

            current.activeBlocklist = blocklist
            current.activeBlockAsWhitelist = isAllowlist
            current.blockEndDate = endDate
            current.blockIsRunning = true
            current.evaluateCommonSubdomains = settings.evaluateCommonSubdomains
            current.includeLinkedDomains = settings.includeLinkedDomains
            current.blockSoundShouldPlay = settings.blockSoundShouldPlay
            current.blockSound = settings.blockSound
            current.clearCaches = settings.clearCaches
            current.allowLocalNetworks = settings.allowLocalNetworks
            current.enableErrorReporting = settings.enableErrorReporting

            let manager = BlockManager(isAllowlist: isAllowlist,
                                       allowLocal: current.allowLocalNetworks,
                                       includeCommonSubdomains: current.evaluateCommonSubdomains,
                                       includeLinkedDomains: current.includeLinkedDomains)
            manager.prepareToAddBlock()
            manager.addBlockEntries(from: blocklist)
            manager.finalizeBlock()

            try settingsStore.save(current)
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    func updateBlocklist(_ newBlocklist: [String], authorization: Data?, withReply reply: @escaping (NSError?) -> Void) {
        do {
            var current = try settingsStore.load()
            if !BlockState.isRunning(settings: current) {
                reply(SelfControlError.make(.blockNotRunning, description: "Block not running"))
                return
            }
            if current.activeBlockAsWhitelist {
                reply(SelfControlError.make(.updateNotAllowedForAllowlist, description: "Allowlist blocks cannot be updated"))
                return
            }

            let existing = Set(current.activeBlocklist)
            let incoming = Set(newBlocklist)
            let added = Array(incoming.subtracting(existing))

            let manager = BlockManager(isAllowlist: current.activeBlockAsWhitelist,
                                       allowLocal: current.allowLocalNetworks,
                                       includeCommonSubdomains: current.evaluateCommonSubdomains,
                                       includeLinkedDomains: current.includeLinkedDomains)
            manager.enterAppendMode()
            manager.addBlockEntries(from: added)
            manager.finishAppending()

            current.activeBlocklist = newBlocklist
            try settingsStore.save(current)
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    func updateBlockEndDate(_ newEndDate: Date, authorization: Data?, withReply reply: @escaping (NSError?) -> Void) {
        do {
            var current = try settingsStore.load()
            if !BlockState.isRunning(settings: current) {
                reply(SelfControlError.make(.blockNotRunning, description: "Block not running"))
                return
            }

            let currentEndDate = current.blockEndDate
            if newEndDate < currentEndDate {
                reply(SelfControlError.make(.endDateEarlierThanCurrent, description: "Cannot shorten block"))
                return
            }
            if newEndDate.timeIntervalSince(currentEndDate) > 86400 {
                reply(SelfControlError.make(.endDateTooFarInFuture, description: "Cannot extend by more than 24 hours"))
                return
            }

            current.blockEndDate = newEndDate
            try settingsStore.save(current)
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    func getVersion(withReply reply: @escaping (String) -> Void) {
        reply(SelfControlVersion.current)
    }
}
