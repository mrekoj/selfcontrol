import Foundation

public final class PFController {
    public static let pfctlPath = "/sbin/pfctl"
    public static let pfConfPath = "/etc/pf.conf"

    private let anchorName: String
    private let anchorPath: String
    private let runner: CommandRunner
    private let lock = NSLock()

    private var rules: [String] = []
    private var appendHandle: FileHandle?

    public init(anchorName: String = "com.skynet", runner: CommandRunner = ProcessCommandRunner()) {
        self.anchorName = anchorName
        self.anchorPath = "/etc/pf.anchors/\(anchorName)"
        self.runner = runner
    }

    public static func blockFoundInPF(anchorName: String = "com.skynet") -> Bool {
        guard let mainConf = try? String(contentsOfFile: pfConfPath, encoding: .utf8) else { return false }
        return mainConf.contains(anchorName)
    }

    public func addRule(ip: String?, port: Int, maskLen: Int, allowlist: Bool) {
        lock.lock()
        defer { lock.unlock() }

        let builder = PFRuleBuilder(isAllowlist: allowlist, anchorName: anchorName)
        let ruleStrings = builder.ruleStrings(ip: ip, port: port, maskLen: maskLen)
        if let handle = appendHandle {
            for rule in ruleStrings {
                if let data = rule.data(using: .utf8) {
                    try? handle.write(contentsOf: data)
                }
            }
        } else {
            rules.append(contentsOf: ruleStrings)
        }
    }

    public func writeConfiguration(allowlist: Bool) {
        let builder = PFRuleBuilder(isAllowlist: allowlist, anchorName: anchorName)
        let config = builder.buildConfig(with: rules)
        try? config.write(toFile: anchorPath, atomically: true, encoding: .utf8)
    }

    public func enterAppendMode() {
        guard appendHandle == nil else { return }
        appendHandle = FileHandle(forWritingAtPath: anchorPath)
        _ = try? appendHandle?.seekToEnd()
    }

    public func finishAppending() {
        try? appendHandle?.close()
        appendHandle = nil
    }

    public func addSelfControlConfig() {
        let existing = (try? String(contentsOfFile: SelfControlPF.pfConfPath, encoding: .utf8)) ?? ""
        if existing.contains(anchorPath) {
            return
        }

        var updated = existing
        updated.append("\nanchor \"\(anchorName)\"\n")
        updated.append("load anchor \"\(anchorName)\" from \"\(anchorPath)\"\n")
        try? updated.write(toFile: SelfControlPF.pfConfPath, atomically: true, encoding: .utf8)
    }

    public func startBlock(allowlist: Bool) -> Int32 {
        addSelfControlConfig()
        writeConfiguration(allowlist: allowlist)

        let result = runner.run(SelfControlPF.pfctlPath, ["-E", "-f", SelfControlPF.pfConfPath, "-F", "states"])
        if let token = parseToken(from: result.output) {
            try? token.write(toFile: SelfControlPF.pfTokenPath, atomically: true, encoding: .utf8)
        }
        return result.exitCode
    }

    public func refreshPFRules() -> Int32 {
        runner.run(SelfControlPF.pfctlPath, ["-f", SelfControlPF.pfConfPath, "-F", "states"]).exitCode
    }

    public func stopBlock(force: Bool) -> Int32 {
        let token = try? String(contentsOfFile: SelfControlPF.pfTokenPath, encoding: .utf8)

        _ = try? "".write(toFile: anchorPath, atomically: true, encoding: .utf8)

        if let mainConf = try? String(contentsOfFile: SelfControlPF.pfConfPath, encoding: .utf8) {
            let lines = mainConf.split(separator: "\n", omittingEmptySubsequences: false)
            let filtered = lines.filter { !$0.contains(anchorName) }
            var newConf = filtered.joined(separator: "\n")
            newConf = newConf.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            try? newConf.write(toFile: SelfControlPF.pfConfPath, atomically: true, encoding: .utf8)
        }

        let args: [String]
        if let token, !token.isEmpty, !force {
            args = ["-X", token, "-f", SelfControlPF.pfConfPath]
        } else {
            args = ["-d", "-f", SelfControlPF.pfConfPath]
        }
        return runner.run(SelfControlPF.pfctlPath, args).exitCode
    }

    public func containsSelfControlBlock() -> Bool {
        guard let mainConf = try? String(contentsOfFile: SelfControlPF.pfConfPath, encoding: .utf8) else { return false }
        return mainConf.contains(anchorName)
    }

    private func parseToken(from output: String) -> String? {
        let lines = output.split(separator: "\n")
        for line in lines {
            if line.hasPrefix("Token : ") {
                return String(line.dropFirst("Token : ".count))
            }
        }
        return nil
    }
}

public enum SelfControlPF {
    public static let pfctlPath = PFController.pfctlPath
    public static let pfConfPath = PFController.pfConfPath
    public static let pfTokenPath = "/etc/SelfControlPFToken"
}
