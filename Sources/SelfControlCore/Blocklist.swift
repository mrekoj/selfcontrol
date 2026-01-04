import Foundation

public struct BlockEntry: Hashable, Codable, CustomStringConvertible {
    public let hostname: String
    public let port: Int
    public let maskLen: Int

    public init(hostname: String, port: Int = 0, maskLen: Int = 0) {
        self.hostname = hostname
        self.port = port
        self.maskLen = maskLen
    }

    public static func from(raw: String) -> BlockEntry? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        var hostname = ""
        var maskLen = 0
        var port = 0

        let slashSplit = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        if let first = slashSplit.first {
            hostname = String(first)
        }

        var searchForPort = hostname
        if slashSplit.count >= 2 {
            let maskCandidate = String(slashSplit[1])
            maskLen = Int(maskCandidate) ?? 0
            searchForPort = maskCandidate
        }

        let colonSplit = searchForPort.split(separator: ":", omittingEmptySubsequences: false)
        if searchForPort == hostname, let first = colonSplit.first {
            hostname = String(first)
        }
        if colonSplit.count >= 2 {
            port = Int(colonSplit[1]) ?? 0
        }

        if hostname.isEmpty {
            hostname = "*"
        }

        if hostname == "*" && port == 0 {
            return nil
        }

        return BlockEntry(hostname: hostname, port: port, maskLen: maskLen)
    }

    public var description: String {
        "[Entry: hostname = \(hostname), port = \(port), maskLen = \(maskLen)]"
    }
}

public enum BlocklistCleaner {
    public static func cleanEntry(_ raw: String?) -> [String] {
        guard var str = raw else { return [] }

        str = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if str.isEmpty { return [] }

        if str.rangeOfCharacter(from: .newlines) != nil {
            let splitEntries = str.components(separatedBy: .newlines)
            var results: [String] = []
            for entry in splitEntries {
                results.append(contentsOf: cleanEntry(entry))
            }
            return results
        }

        // Strip scheme
        if let range = str.range(of: "://") {
            str = String(str[range.upperBound...])
        }

        // Strip user:pass@host
        if let atIndex = str.lastIndex(of: "@") {
            str = String(str[str.index(after: atIndex)...])
        }

        var cidrMaskBits = -1
        var portNum = -1

        let slashSplit = str.components(separatedBy: "/")
        str = slashSplit.first ?? ""
        if slashSplit.count > 1 {
            let potentialMask = Int(slashSplit.last ?? "") ?? 0
            if potentialMask > 0 && potentialMask <= 128 {
                cidrMaskBits = potentialMask
            }
        }

        let colonSplit = str.components(separatedBy: ":")
        str = colonSplit.first ?? ""
        if colonSplit.count > 1 {
            let potentialPort = Int(colonSplit.last ?? "") ?? 0
            if potentialPort > 0 && potentialPort <= 65535 {
                portNum = potentialPort
            }
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._"))
        var validCharsOnly = ""
        validCharsOnly.reserveCapacity(min(str.count, 253))
        for scalar in str.unicodeScalars.prefix(253) {
            if allowed.contains(scalar) {
                validCharsOnly.unicodeScalars.append(scalar)
            }
        }
        str = validCharsOnly

        if str.isEmpty && portNum < 0 {
            return []
        }

        let maskString = cidrMaskBits < 0 ? "" : "/\(cidrMaskBits)"
        let portString = portNum < 0 ? "" : ":\(portNum)"

        return ["\(str)\(maskString)\(portString)"]
    }

    public static func cleanBlocklist(_ entries: [String]) -> [String] {
        var cleaned: [String] = []
        cleaned.reserveCapacity(entries.count)
        for entry in entries {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                cleaned.append(trimmed)
            }
        }
        return cleaned
    }
}
