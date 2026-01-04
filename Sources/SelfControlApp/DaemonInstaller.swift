import Foundation
import ServiceManagement
import SelfControlCore

@MainActor
final class DaemonInstaller: ObservableObject {
    @Published private(set) var state: SMAppService.Status = .notRegistered

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        let service = SMAppService.daemon(plistName: "\(BundleIdentifiers.daemon).plist")
        state = service.status
    }

    func register() throws {
        let service = SMAppService.daemon(plistName: "\(BundleIdentifiers.daemon).plist")
        try service.register()
        refreshStatus()
    }

    func unregister() throws {
        let service = SMAppService.daemon(plistName: "\(BundleIdentifiers.daemon).plist")
        try service.unregister()
        refreshStatus()
    }
}
