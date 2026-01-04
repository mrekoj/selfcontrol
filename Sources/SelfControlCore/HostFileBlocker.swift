import Foundation

public final class HostFileBlocker {
    public static let defaultPath = "/etc/hosts"
    public static let header = "# BEGIN SELFCONTROL BLOCK"
    public static let footer = "# END SELFCONTROL BLOCK"

    private static let defaultHostsFileContents = "##\n# Host Database\n#\n# localhost is used to configure the loopback interface\n# when the system is booting.  Do not change this entry.\n##\n127.0.0.1\tlocalhost\n255.255.255.255\tbroadcasthost\n::1             localhost\nfe80::1%lo0\tlocalhost\n\n"

    private let fileManager: FileManager
    private let hostFilePath: String
    private let lock = NSLock()
    private var newFileContents: String
    private var stringEncoding: String.Encoding

    public init(path: String = HostFileBlocker.defaultPath, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.hostFilePath = path
        self.stringEncoding = .utf8

        if let contents = try? String(contentsOfFile: path, usedEncoding: &self.stringEncoding) {
            self.newFileContents = contents
        } else {
            self.newFileContents = HostFileBlocker.defaultHostsFileContents
        }
    }

    public static func blockFoundInHostsFile(path: String = HostFileBlocker.defaultPath) -> Bool {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
        return contents.contains(HostFileBlocker.header)
    }

    public func revertFileContentsToDisk() {
        lock.lock()
        defer { lock.unlock() }

        if let contents = try? String(contentsOfFile: hostFilePath, usedEncoding: &stringEncoding) {
            newFileContents = contents
        } else {
            newFileContents = HostFileBlocker.defaultHostsFileContents
        }
    }

    public func writeNewFileContents() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        do {
            try newFileContents.write(toFile: hostFilePath, atomically: true, encoding: stringEncoding)
            return true
        } catch {
            return false
        }
    }

    public func createBackupHostsFile() -> Bool {
        deleteBackupHostsFile()

        if !fileManager.fileExists(atPath: hostFilePath) {
            do {
                try HostFileBlocker.defaultHostsFileContents.write(toFile: hostFilePath, atomically: true, encoding: .utf8)
            } catch {
                return false
            }
        }

        if !fileManager.isReadableFile(atPath: hostFilePath) || fileManager.fileExists(atPath: backupHostFilePath()) {
            return false
        }

        do {
            try fileManager.copyItem(atPath: hostFilePath, toPath: backupHostFilePath())
            return true
        } catch {
            return false
        }
    }

    public func deleteBackupHostsFile() {
        if fileManager.isDeletableFile(atPath: backupHostFilePath()) {
            try? fileManager.removeItem(atPath: backupHostFilePath())
        }
    }

    public func restoreBackupHostsFile() -> Bool {
        let backupPath = backupHostFilePath()
        do {
            try fileManager.removeItem(atPath: hostFilePath)
            guard fileManager.isReadableFile(atPath: backupPath) else { return false }
            try fileManager.moveItem(atPath: backupPath, toPath: hostFilePath)
            return true
        } catch {
            return false
        }
    }

    public func addSelfControlBlockHeader() {
        lock.lock()
        defer { lock.unlock() }
        newFileContents.append("\n")
        newFileContents.append(HostFileBlocker.header)
        newFileContents.append("\n")
    }

    public func addSelfControlBlockFooter() {
        lock.lock()
        defer { lock.unlock() }
        newFileContents.append(HostFileBlocker.footer)
        newFileContents.append("\n")
    }

    public func addRuleBlockingDomain(_ domainName: String) {
        lock.lock()
        defer { lock.unlock() }
        for rule in ruleStringsToBlock(domainName) {
            newFileContents.append(rule)
        }
    }

    public func appendExistingBlock(with domainName: String) {
        lock.lock()
        defer { lock.unlock() }

        guard let range = newFileContents.range(of: HostFileBlocker.footer) else {
            return
        }
        let combined = ruleStringsToBlock(domainName).joined()
        newFileContents.insert(contentsOf: combined, at: range.lowerBound)
    }

    public func containsSelfControlBlock() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return newFileContents.contains(HostFileBlocker.header)
    }

    public func removeSelfControlBlock() {
        guard containsSelfControlBlock() else { return }
        lock.lock()
        defer { lock.unlock() }

        guard let startRange = newFileContents.range(of: HostFileBlocker.header) else { return }
        let endRange = newFileContents.range(of: HostFileBlocker.footer)

        var deleteStart = startRange.lowerBound
        if deleteStart > newFileContents.startIndex {
            let prevIndex = newFileContents.index(before: deleteStart)
            if newFileContents[prevIndex].isNewline {
                deleteStart = prevIndex
            }
        }

        var deleteEnd: String.Index
        if let endRange {
            deleteEnd = endRange.upperBound
            if deleteEnd < newFileContents.endIndex {
                let next = newFileContents[deleteEnd]
                if next.isNewline {
                    deleteEnd = newFileContents.index(after: deleteEnd)
                }
            }
        } else {
            deleteEnd = newFileContents.endIndex
        }

        newFileContents.removeSubrange(deleteStart..<deleteEnd)
    }

    private func backupHostFilePath() -> String {
        hostFilePath + ".bak"
    }

    private func ruleStringsToBlock(_ domainName: String) -> [String] {
        [
            "0.0.0.0\t\(domainName)\n",
            "::\t\(domainName)\n"
        ]
    }
}
