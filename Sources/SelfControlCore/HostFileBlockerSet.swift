import Foundation

public final class HostFileBlockerSet {
    public let defaultBlocker: HostFileBlocker
    public let blockers: [HostFileBlocker]

    public init(paths: [String]? = nil, fileManager: FileManager = .default) {
        if let paths {
            let items = paths.map { HostFileBlocker(path: $0, fileManager: fileManager) }
            self.defaultBlocker = items.first ?? HostFileBlocker(fileManager: fileManager)
            self.blockers = items
            return
        }

        let commonBackupHostFilePaths = [
            "/etc/pulse-hosts.bak",
            "/etc/jnpr-pulse-hosts.bak",
            "/etc/pulse.hosts.bak",
            "/etc/jnpr-nc-hosts.bak",
            "/etc/hosts.ac"
        ]

        var hostFileBlockers: [HostFileBlocker] = []
        let defaultBlocker = HostFileBlocker(fileManager: fileManager)
        hostFileBlockers.append(defaultBlocker)

        for path in commonBackupHostFilePaths where fileManager.isReadableFile(atPath: path) {
            hostFileBlockers.append(HostFileBlocker(path: path, fileManager: fileManager))
        }

        self.defaultBlocker = defaultBlocker
        self.blockers = hostFileBlockers
    }

    public func deleteBackupHostsFile() -> Bool {
        for blocker in blockers {
            blocker.deleteBackupHostsFile()
        }
        return true
    }

    public func revertFileContentsToDisk() {
        blockers.forEach { $0.revertFileContentsToDisk() }
    }

    public func writeNewFileContents() -> Bool {
        var result = true
        for blocker in blockers {
            result = result && blocker.writeNewFileContents()
        }
        return result
    }

    public func addSelfControlBlockHeader() {
        blockers.forEach { $0.addSelfControlBlockHeader() }
    }

    public func addSelfControlBlockFooter() {
        blockers.forEach { $0.addSelfControlBlockFooter() }
    }

    public func createBackupHostsFile() -> Bool {
        var result = true
        for blocker in blockers {
            result = result && blocker.createBackupHostsFile()
        }
        return result
    }

    public func restoreBackupHostsFile() -> Bool {
        var result = true
        for blocker in blockers {
            result = result && blocker.restoreBackupHostsFile()
        }
        return result
    }

    public func addRuleBlockingDomain(_ domainName: String) {
        blockers.forEach { $0.addRuleBlockingDomain(domainName) }
    }

    public func appendExistingBlock(with domainName: String) {
        blockers.forEach { $0.appendExistingBlock(with: domainName) }
    }

    public func containsSelfControlBlock() -> Bool {
        blockers.contains { $0.containsSelfControlBlock() }
    }

    public func removeSelfControlBlock() {
        blockers.forEach { $0.removeSelfControlBlock() }
    }
}
