import Foundation
import CryptoKit
import IOKit

public enum Hashing {
    public static func sha1(_ value: String) -> String {
        let data = Data(value.utf8)
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public enum SystemInfo {
    public static func serialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }

        if let cf = IORegistryEntryCreateCFProperty(platformExpert,
                                                    kIOPlatformSerialNumberKey as CFString,
                                                    kCFAllocatorDefault,
                                                    0) {
            return (cf.takeRetainedValue() as? String)
        }
        return nil
    }
}
