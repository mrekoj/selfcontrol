import Foundation
import Security

public enum AuthCommand: CaseIterable, Hashable {
    case startBlock
    case updateBlocklist
    case updateBlockEndDate
    case clearBlock

    public var rightName: String {
        switch self {
        case .startBlock:
            return "com.skynet.selfcontrol.startBlock"
        case .updateBlocklist:
            return "com.skynet.selfcontrol.updateBlocklist"
        case .updateBlockEndDate:
            return "com.skynet.selfcontrol.updateBlockEndDate"
        case .clearBlock:
            return "com.skynet.selfcontrol.clearBlock"
        }
    }

    public var promptDescription: String {
        switch self {
        case .startBlock:
            return "Start a SkyControl block"
        case .updateBlocklist:
            return "Update a running SkyControl block"
        case .updateBlockEndDate:
            return "Extend a running SkyControl block"
        case .clearBlock:
            return "Emergency unlock (clear SkyControl block)"
        }
    }
}

public enum AuthorizationManager {
    public static func authorizationData(for command: AuthCommand) throws -> Data {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)
        guard status == errAuthorizationSuccess, let authRef else {
            throw SelfControlError.make(.authorizationFailed, description: "AuthorizationCreate failed: \(status)")
        }

        try setupRights(authRef)

        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        let copyStatus = command.rightName.withCString { cstr -> OSStatus in
            var authItem = AuthorizationItem(name: cstr, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &authItem) { itemPtr in
                var authRights = AuthorizationRights(count: 1, items: itemPtr)
                return AuthorizationCopyRights(authRef, &authRights, nil, flags, nil)
            }
        }
        guard copyStatus == errAuthorizationSuccess else {
            AuthorizationFree(authRef, [])
            throw SelfControlError.make(.authorizationFailed, description: "AuthorizationCopyRights failed: \(copyStatus)")
        }

        var extForm = AuthorizationExternalForm()
        let extStatus = AuthorizationMakeExternalForm(authRef, &extForm)
        AuthorizationFree(authRef, [])
        guard extStatus == errAuthorizationSuccess else {
            throw SelfControlError.make(.authorizationFailed, description: "AuthorizationMakeExternalForm failed: \(extStatus)")
        }

        return Data(bytes: &extForm, count: MemoryLayout.size(ofValue: extForm))
    }

    public static func verifyAuthorization(_ authData: Data?, command: AuthCommand) throws {
        if shouldBypassAuthorization() {
            return
        }
        guard let authData else {
            throw SelfControlError.make(.authorizationFailed, description: "Missing authorization data")
        }
        guard authData.count == MemoryLayout<AuthorizationExternalForm>.size else {
            throw SelfControlError.make(.authorizationFailed, description: "Invalid authorization data")
        }

        var extForm = AuthorizationExternalForm()
        _ = withUnsafeMutableBytes(of: &extForm) { authData.copyBytes(to: $0) }

        var authRef: AuthorizationRef?
        let status = AuthorizationCreateFromExternalForm(&extForm, &authRef)
        guard status == errAuthorizationSuccess, let authRef else {
            throw SelfControlError.make(.authorizationFailed, description: "AuthorizationCreateFromExternalForm failed: \(status)")
        }

        let flags: AuthorizationFlags = []
        let rightsStatus = command.rightName.withCString { cstr -> OSStatus in
            var authItem = AuthorizationItem(name: cstr, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &authItem) { itemPtr in
                var authRights = AuthorizationRights(count: 1, items: itemPtr)
                return AuthorizationCopyRights(authRef, &authRights, nil, flags, nil)
            }
        }
        AuthorizationFree(authRef, [])
        guard rightsStatus == errAuthorizationSuccess else {
            throw SelfControlError.make(.authorizationFailed, description: "AuthorizationCopyRights failed: \(rightsStatus)")
        }
    }

    private static func shouldBypassAuthorization() -> Bool {
        if ProcessInfo.processInfo.environment["SELFCONTROL_DEV_BYPASS_AUTH"] == "1" {
            return true
        }
        return FileManager.default.fileExists(atPath: "/Library/PrivilegedHelperTools/com.skynet.selfcontrold.dev")
    }

    private static func setupRights(_ authRef: AuthorizationRef) throws {
        for command in AuthCommand.allCases {
            try command.rightName.withCString { cstr in
                var rightDefinition: CFDictionary?
                let getStatus = AuthorizationRightGet(cstr, &rightDefinition)
                if getStatus == errAuthorizationDenied {
                    let description = command.promptDescription as CFString
                    let rule = kAuthorizationRuleAuthenticateAsAdmin as CFString
                    let setStatus = AuthorizationRightSet(authRef, cstr, rule, description, nil, nil)
                    if setStatus != errAuthorizationSuccess {
                        throw SelfControlError.make(.authorizationFailed, description: "AuthorizationRightSet failed: \(setStatus)")
                    }
                } else if getStatus != errAuthorizationSuccess {
                    throw SelfControlError.make(.authorizationFailed, description: "AuthorizationRightGet failed: \(getStatus)")
                }
            }
        }
    }
}
