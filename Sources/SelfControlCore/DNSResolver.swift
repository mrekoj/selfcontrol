import Foundation
import CFNetwork

public enum DNSResolver {
    public static func ipAddresses(for domainName: String) -> [String] {
        guard !domainName.isEmpty else { return [] }

        let started = Date()
        let hostRef = CFHostCreateWithName(kCFAllocatorDefault, domainName as CFString)
        let host = hostRef.takeRetainedValue()
        var streamError = CFStreamError()
        CFHostStartInfoResolution(host, .addresses, &streamError)
        if streamError.error != 0 {
            return []
        }

        var success: DarwinBoolean = false
        guard let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as? [Data], success.boolValue else {
            return []
        }

        var results: [String] = []
        for data in addresses {
            if let ip = string(for: data) {
                results.append(ip)
            }
        }

        let elapsed = Date().timeIntervalSince(started)
        if elapsed > 2.5 {
            NSLog("DNSResolver: warning, resolving %@ took %.2fs", domainName, elapsed)
        }

        return results
    }

    private static func string(for addressData: Data) -> String? {
        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = addressData.withUnsafeBytes { rawPtr -> Int32 in
            let sockaddrPtr = rawPtr.bindMemory(to: sockaddr.self)
            return getnameinfo(sockaddrPtr.baseAddress, socklen_t(addressData.count), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST)
        }
        guard result == 0 else { return nil }
        return String(cString: hostBuffer)
    }
}
