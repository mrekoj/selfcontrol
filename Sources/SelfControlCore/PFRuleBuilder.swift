import Foundation

public struct PFRuleBuilder {
    public let isAllowlist: Bool
    public let anchorName: String

    public init(isAllowlist: Bool, anchorName: String = "com.skynet") {
        self.isAllowlist = isAllowlist
        self.anchorName = anchorName
    }

    public func header() -> String {
        var text = ""
        text += "# Options\n"
        text += "set block-policy drop\n"
        text += "set fingerprints \"/etc/pf.os\"\n"
        text += "set ruleset-optimization basic\n"
        text += "set skip on lo0\n\n"
        text += "#\n# \(anchorName) ruleset for SelfControl blocks\n#\n"

        if isAllowlist {
            text += "block return out proto tcp from any to any\n"
            text += "block return out proto udp from any to any\n\n"
        }
        return text
    }

    public func allowlistFooter() -> String {
        guard isAllowlist else { return "" }
        return [
            "pass out proto tcp from any to any port 53\n",
            "pass out proto udp from any to any port 53\n",
            "pass out proto udp from any to any port 123\n",
            "pass out proto udp from any to any port 67\n",
            "pass out proto tcp from any to any port 67\n",
            "pass out proto udp from any to any port 68\n",
            "pass out proto tcp from any to any port 68\n",
            "pass out proto udp from any to any port 5353\n",
            "pass out proto tcp from any to any port 5353\n"
        ].joined()
    }

    public func ruleStrings(ip: String?, port: Int, maskLen: Int) -> [String] {
        var rule = "from any to "
        rule += ip ?? "any"

        if maskLen > 0 {
            rule += "/\(maskLen)"
        }
        if port > 0 {
            rule += " port \(port)"
        }

        if isAllowlist {
            return [
                "pass out proto tcp \(rule)\n",
                "pass out proto udp \(rule)\n"
            ]
        }
        return [
            "block return out proto tcp \(rule)\n",
            "block return out proto udp \(rule)\n"
        ]
    }

    public func buildConfig(with rules: [String]) -> String {
        var config = header()
        for rule in rules {
            config += rule
        }
        config += allowlistFooter()
        return config
    }
}
