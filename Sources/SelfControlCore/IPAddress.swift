import Foundation
import Darwin

public enum IPAddressValidator {
    public static func isValidIPv4(_ value: String) -> Bool {
        var addr = in_addr()
        return value.withCString { inet_pton(AF_INET, $0, &addr) } == 1
    }

    public static func isValidIPv6(_ value: String) -> Bool {
        var addr = in6_addr()
        return value.withCString { inet_pton(AF_INET6, $0, &addr) } == 1
    }

    public static func isValidIP(_ value: String) -> Bool {
        isValidIPv4(value) || isValidIPv6(value)
    }
}
