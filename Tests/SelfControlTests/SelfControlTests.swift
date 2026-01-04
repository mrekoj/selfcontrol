import XCTest
@testable import SelfControlCore

final class SelfControlTests: XCTestCase {
    func testVersionIsPresent() {
        XCTAssertFalse(SelfControlVersion.current.isEmpty)
    }

    func testCleanBlocklistEntries() {
        XCTAssertEqual(BlocklistCleaner.cleanEntry(nil).count, 0)
        XCTAssertEqual(BlocklistCleaner.cleanEntry("").count, 0)
        XCTAssertEqual(BlocklistCleaner.cleanEntry("      ").count, 0)
        XCTAssertEqual(BlocklistCleaner.cleanEntry("  \n\n   \n***!@#$%^*()+=<>,/?| ").count, 0)
        XCTAssertEqual(BlocklistCleaner.cleanEntry("://}**").count, 0)

        var cleaned = BlocklistCleaner.cleanEntry("selfcontrolapp.com")
        XCTAssertEqual(cleaned.count, 1)
        XCTAssertEqual(cleaned.first, "selfcontrolapp.com")

        cleaned = BlocklistCleaner.cleanEntry("selFconTROLapp.com")
        XCTAssertEqual(cleaned.count, 1)
        XCTAssertEqual(cleaned.first, "selfcontrolapp.com")

        cleaned = BlocklistCleaner.cleanEntry("www.selFconTROLapp.com")
        XCTAssertEqual(cleaned.first, "www.selfcontrolapp.com")

        cleaned = BlocklistCleaner.cleanEntry("http://www.selFconTROLapp.com")
        XCTAssertEqual(cleaned.first, "www.selfcontrolapp.com")

        cleaned = BlocklistCleaner.cleanEntry("https://www.selFconTROLapp.com")
        XCTAssertEqual(cleaned.first, "www.selfcontrolapp.com")

        cleaned = BlocklistCleaner.cleanEntry("ftp://www.selFconTROLapp.com")
        XCTAssertEqual(cleaned.first, "www.selfcontrolapp.com")

        cleaned = BlocklistCleaner.cleanEntry("https://www.selFconTROLapp.com:73")
        XCTAssertEqual(cleaned.first, "www.selfcontrolapp.com:73")

        cleaned = BlocklistCleaner.cleanEntry("http://charlie:mypass@cnn.com:54")
        XCTAssertEqual(cleaned.first, "cnn.com:54")

        cleaned = BlocklistCleaner.cleanEntry("http://mysite.com/my/path/is/very/long.php?querystring=ydfjkl&otherquerystring=%40%80%20#cool")
        XCTAssertEqual(cleaned.first, "mysite.com")

        cleaned = BlocklistCleaner.cleanEntry("127.0.0.1/20")
        XCTAssertEqual(cleaned.first, "127.0.0.1/20")

        cleaned = BlocklistCleaner.cleanEntry("http://charlie:mypass@cnn.com:54\nhttps://selfcontrolAPP.com\n192.168.1.1/24\ntest.com\n{}*&\nhttps://reader.google.com/mypath/is/great.php")
        XCTAssertEqual(cleaned.count, 5)
        XCTAssertEqual(cleaned[0], "cnn.com:54")
        XCTAssertEqual(cleaned[1], "selfcontrolapp.com")
        XCTAssertEqual(cleaned[2], "192.168.1.1/24")
        XCTAssertEqual(cleaned[3], "test.com")
        XCTAssertEqual(cleaned[4], "reader.google.com")
    }

    func testBlockEntryParsing() {
        XCTAssertNil(BlockEntry.from(raw: ""))
        XCTAssertNil(BlockEntry.from(raw: "   \n"))

        let entry1 = BlockEntry.from(raw: "example.com")
        XCTAssertEqual(entry1?.hostname, "example.com")
        XCTAssertEqual(entry1?.port, 0)
        XCTAssertEqual(entry1?.maskLen, 0)

        let entry2 = BlockEntry.from(raw: "1.2.3.4/24")
        XCTAssertEqual(entry2?.hostname, "1.2.3.4")
        XCTAssertEqual(entry2?.maskLen, 24)

        let entry3 = BlockEntry.from(raw: "example.com:443")
        XCTAssertEqual(entry3?.hostname, "example.com")
        XCTAssertEqual(entry3?.port, 443)

        let entry4 = BlockEntry.from(raw: ":80")
        XCTAssertEqual(entry4?.hostname, "*")
        XCTAssertEqual(entry4?.port, 80)

        let entry5 = BlockEntry.from(raw: "*:")
        XCTAssertNil(entry5)
    }
}

extension SelfControlTests {
    func testIPAddressValidation() {
        XCTAssertTrue(IPAddressValidator.isValidIPv4("127.0.0.1"))
        XCTAssertFalse(IPAddressValidator.isValidIPv4("999.0.0.1"))
        XCTAssertTrue(IPAddressValidator.isValidIPv6("::1"))
        XCTAssertFalse(IPAddressValidator.isValidIPv6(":::"))
        XCTAssertTrue(IPAddressValidator.isValidIP("127.0.0.1"))
        XCTAssertTrue(IPAddressValidator.isValidIP("::1"))
        XCTAssertFalse(IPAddressValidator.isValidIP("not-an-ip"))
    }
}

extension SelfControlTests {
    func testSettingsStoreRoundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = tempDir.appendingPathComponent("settings.plist")
        let store = SettingsStore(url: fileURL)

        let loadedDefault = try store.load()
        XCTAssertEqual(loadedDefault, Settings.defaults)

        var updated = Settings.defaults
        updated.activeBlocklist = ["example.com"]

        let fixedDate = Date(timeIntervalSince1970: 123)
        try store.save(updated, date: fixedDate)

        let loaded = try store.load()
        XCTAssertEqual(loaded.activeBlocklist, ["example.com"])
        XCTAssertEqual(loaded.settingsVersionNumber, Settings.defaults.settingsVersionNumber + 1)
        XCTAssertEqual(loaded.lastSettingsUpdate, fixedDate)
    }

    func testSettingsPathGeneration() {
        let name = SettingsPaths.fileName(serialNumber: "SERIAL123")
        XCTAssertTrue(name.hasPrefix("."))
        XCTAssertTrue(name.hasSuffix(".plist"))
        XCTAssertGreaterThan(name.count, 10)
    }
}

extension SelfControlTests {
    func testPFRuleBuilder() {
        let blockBuilder = PFRuleBuilder(isAllowlist: false, anchorName: "com.skynet")
        let blockRules = blockBuilder.ruleStrings(ip: "1.2.3.4", port: 443, maskLen: 24)
        XCTAssertEqual(blockRules[0], "block return out proto tcp from any to 1.2.3.4/24 port 443\n")
        XCTAssertEqual(blockRules[1], "block return out proto udp from any to 1.2.3.4/24 port 443\n")

        let allowBuilder = PFRuleBuilder(isAllowlist: true, anchorName: "com.skynet")
        let allowRules = allowBuilder.ruleStrings(ip: nil, port: 0, maskLen: 0)
        XCTAssertEqual(allowRules[0], "pass out proto tcp from any to any\n")
        XCTAssertEqual(allowRules[1], "pass out proto udp from any to any\n")

        let config = allowBuilder.buildConfig(with: allowRules)
        XCTAssertTrue(config.contains("# com.skynet ruleset for SelfControl blocks"))
        XCTAssertTrue(config.contains("block return out proto tcp from any to any"))
        XCTAssertTrue(config.contains("pass out proto tcp from any to any port 53"))
    }
}

extension SelfControlTests {
    func testBlockSettingsCoding() throws {
        let settings = BlockSettings(
            evaluateCommonSubdomains: true,
            includeLinkedDomains: false,
            blockSoundShouldPlay: true,
            blockSound: 3,
            clearCaches: true,
            allowLocalNetworks: false,
            enableErrorReporting: false
        )
        let data = try NSKeyedArchiver.archivedData(withRootObject: settings, requiringSecureCoding: true)
        let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: BlockSettings.self, from: data)
        XCTAssertEqual(decoded?.blockSound, 3)
        XCTAssertEqual(decoded?.evaluateCommonSubdomains, true)
        XCTAssertEqual(decoded?.includeLinkedDomains, false)
    }
}
