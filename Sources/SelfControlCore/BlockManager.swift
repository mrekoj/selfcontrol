import Foundation

public final class BlockManager {
    private let pf: PFController
    private let hostBlockerSet: HostFileBlockerSet

    private let isAllowlist: Bool
    private let allowLocal: Bool
    private let includeCommonSubdomains: Bool
    private let includeLinkedDomains: Bool

    private var hostsBlockingEnabled = false
    private var appendMode = false
    private var addedBlockEntries: Set<BlockEntry> = []

    public init(isAllowlist: Bool,
                allowLocal: Bool = true,
                includeCommonSubdomains: Bool = true,
                includeLinkedDomains: Bool = true,
                pf: PFController = PFController(),
                hostBlockerSet: HostFileBlockerSet = HostFileBlockerSet()) {
        self.isAllowlist = isAllowlist
        self.allowLocal = allowLocal
        self.includeCommonSubdomains = includeCommonSubdomains
        self.includeLinkedDomains = includeLinkedDomains
        self.pf = pf
        self.hostBlockerSet = hostBlockerSet
    }

    public func prepareToAddBlock() {
        for blocker in hostBlockerSet.blockers where blocker.containsSelfControlBlock() {
            blocker.removeSelfControlBlock()
            _ = blocker.writeNewFileContents()
        }

        if !isAllowlist && !hostBlockerSet.defaultBlocker.containsSelfControlBlock() {
            _ = hostBlockerSet.createBackupHostsFile()
            hostBlockerSet.addSelfControlBlockHeader()
            hostsBlockingEnabled = true
        } else {
            hostsBlockingEnabled = false
        }
    }

    public func enterAppendMode() {
        guard !isAllowlist else { return }
        guard hostBlockerSet.defaultBlocker.containsSelfControlBlock() else { return }
        hostsBlockingEnabled = true
        appendMode = true
        pf.enterAppendMode()
    }

    public func finishAppending() {
        _ = hostBlockerSet.writeNewFileContents()
        pf.finishAppending()
        _ = pf.refreshPFRules()
        appendMode = false
    }

    public func finalizeBlock() {
        if hostsBlockingEnabled {
            hostBlockerSet.addSelfControlBlockFooter()
            _ = hostBlockerSet.writeNewFileContents()
        }
        _ = pf.startBlock(allowlist: isAllowlist)
    }

    public func addBlockEntries(from strings: [String]) {
        for entry in strings {
            addBlockEntry(from: entry)
        }
    }

    public func addBlockEntry(from string: String) {
        guard let entry = BlockEntry.from(raw: string) else { return }

        let related = relatedBlockEntries(for: entry)
        for relatedEntry in related {
            addBlockEntry(entry: relatedEntry)
        }
        addBlockEntry(entry: entry)
    }

    public func clearBlock() -> Bool {
        _ = pf.stopBlock(force: false)
        let pfSuccess = !pf.containsSelfControlBlock()

        hostBlockerSet.removeSelfControlBlock()
        let hostSuccess = hostBlockerSet.writeNewFileContents()
        hostBlockerSet.revertFileContentsToDisk()
        let cleanHosts = !hostBlockerSet.containsSelfControlBlock()

        if !hostSuccess || !cleanHosts {
            _ = hostBlockerSet.restoreBackupHostsFile()
        }

        return pfSuccess && hostSuccess && cleanHosts
    }

    public func blockIsActive() -> Bool {
        hostBlockerSet.defaultBlocker.containsSelfControlBlock() || pf.containsSelfControlBlock()
    }

    private func addBlockEntry(entry: BlockEntry) {
        if addedBlockEntries.contains(entry) { return }
        addedBlockEntries.insert(entry)

        let hostname = entry.hostname
        let isIP = IPAddressValidator.isValidIP(hostname)
        let isIPv4 = IPAddressValidator.isValidIPv4(hostname)

        if hostname == "*" {
            pf.addRule(ip: nil, port: entry.port, maskLen: entry.maskLen, allowlist: isAllowlist)
        } else if isIPv4 {
            pf.addRule(ip: hostname, port: entry.port, maskLen: entry.maskLen, allowlist: isAllowlist)
        } else if !isIP {
            if domainIsGoogle(hostname), isAllowlist {
                addGoogleIPsToPF()
            } else {
                let addresses = DNSResolver.ipAddresses(for: hostname)
                for ip in addresses {
                    pf.addRule(ip: ip, port: entry.port, maskLen: entry.maskLen, allowlist: isAllowlist)
                }
            }
        }

        if hostsBlockingEnabled && hostname != "*" && entry.port == 0 && !isIP {
            if appendMode {
                hostBlockerSet.appendExistingBlock(with: hostname)
            } else {
                hostBlockerSet.addRuleBlockingDomain(hostname)
            }
        }
    }

    private func relatedBlockEntries(for entry: BlockEntry) -> [BlockEntry] {
        guard includeCommonSubdomains || includeLinkedDomains else { return [] }

        var related: [BlockEntry] = []
        if includeLinkedDomains {
            NSLog("BlockManager: includeLinkedDomains requested but not yet implemented")
        }

        if includeCommonSubdomains, !IPAddressValidator.isValidIP(entry.hostname) {
            for subdomain in commonSubdomains(for: entry.hostname) {
                if let parsed = BlockEntry.from(raw: subdomain) {
                    related.append(parsed)
                }
            }
        }

        return related
    }

    private func commonSubdomains(for hostName: String) -> [String] {
        var newHosts: Set<String> = []

        if hostName.hasSuffix("facebook.com") {
            let facebookIPs = [
                "31.13.24.0/21",
                "31.13.64.0/18",
                "45.64.40.0/22",
                "66.220.144.0/20",
                "69.63.176.0/20",
                "69.171.224.0/19",
                "74.119.76.0/22",
                "102.132.96.0/20",
                "103.4.96.0/22",
                "129.134.0.0/16",
                "147.75.208.0/20",
                "157.240.0.0/16",
                "173.252.64.0/18",
                "179.60.192.0/22",
                "185.60.216.0/22",
                "185.89.216.0/22",
                "199.201.64.0/22",
                "204.15.20.0/22"
            ]
            newHosts.formUnion(facebookIPs)
        }
        if hostName.hasSuffix("twitter.com") {
            newHosts.insert("api.twitter.com")
        }
        if hostName.hasSuffix("netflix.com") {
            newHosts.insert("assets.nflxext.com")
            newHosts.insert("codex.nflxext.com")
            newHosts.insert("nflxext.com")
        }

        if hostName.hasPrefix("www.") {
            newHosts.insert(String(hostName.dropFirst(4)))
        } else {
            newHosts.insert("www.\(hostName)")
        }

        return Array(newHosts)
    }

    private func domainIsGoogle(_ domainName: String) -> Bool {
        let regex = "^([a-z0-9]+\\.)*(google|youtube|picasa|sketchup|blogger|blogspot)\\.([a-z]{1,3})(\\.[a-z]{1,3})?$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: domainName)
    }

    private func addGoogleIPsToPF() {
        let googleIPRanges = [
            "8.8.4.0/24",
            "8.34.208.0/20",
            "8.35.192.0/20",
            "23.236.48.0/20",
            "23.251.128.0/19",
            "34.64.0.0/10",
            "34.128.0.0/10",
            "35.184.0.0/13",
            "35.192.0.0/14",
            "35.196.0.0/15",
            "35.198.0.0/16",
            "35.199.0.0/17",
            "35.199.128.0/18",
            "35.200.0.0/13",
            "35.208.0.0/12",
            "35.224.0.0/12",
            "35.240.0.0/13",
            "64.15.112.0/20",
            "64.233.160.0/19",
            "66.102.0.0/20",
            "66.249.64.0/19",
            "70.32.128.0/19",
            "72.14.192.0/18",
            "74.114.24.0/21",
            "74.125.0.0/16",
            "104.154.0.0/16",
            "104.196.0.0/14",
            "104.237.160.0/19",
            "107.167.160.0/19",
            "107.178.192.0/18",
            "108.59.80.0/20",
            "108.170.192.0/18",
            "108.177.0.0/17",
            "130.211.0.0/16",
            "136.112.0.0/12",
            "142.250.0.0/15",
            "146.148.0.0/17",
            "162.216.148.0/22",
            "162.222.176.0/21",
            "172.110.32.0/21",
            "172.217.0.0/16",
            "172.253.0.0/16",
            "173.194.0.0/16",
            "173.255.112.0/20",
            "192.158.28.0/22",
            "192.178.0.0/15",
            "193.186.4.0/24",
            "199.36.154.0/23",
            "199.36.156.0/24",
            "199.192.112.0/22",
            "199.223.232.0/21",
            "207.223.160.0/20",
            "208.65.152.0/22",
            "208.68.108.0/22",
            "208.81.188.0/22",
            "208.117.224.0/19",
            "209.85.128.0/17",
            "216.58.192.0/19",
            "216.73.80.0/20",
            "216.239.32.0/19",
            "2001:4860::/32",
            "2404:6800::/32",
            "2404:f340::/32"
        ]

        for range in googleIPRanges {
            if let entry = BlockEntry.from(raw: range) {
                pf.addRule(ip: entry.hostname, port: entry.port, maskLen: entry.maskLen, allowlist: isAllowlist)
            }
        }
    }
}
