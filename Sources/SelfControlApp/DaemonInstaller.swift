import Foundation
import ServiceManagement
import SelfControlCore

@MainActor
final class DaemonInstaller: ObservableObject {
    @Published private(set) var state: SMAppService.Status = .notRegistered
    private let fileManager = FileManager.default

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        let service = SMAppService.daemon(plistName: "\(BundleIdentifiers.daemon).plist")
        state = service.status
    }

    func register() throws {
        try ensureDaemonPlistPresent()
        let service = SMAppService.daemon(plistName: "\(BundleIdentifiers.daemon).plist")
        try service.register()
        refreshStatus()
    }

    func unregister() throws {
        let service = SMAppService.daemon(plistName: "\(BundleIdentifiers.daemon).plist")
        try service.unregister()
        refreshStatus()
    }

    private func ensureDaemonPlistPresent() throws {
        let targetDir = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchDaemons", isDirectory: true)
        let targetURL = targetDir.appendingPathComponent("\(BundleIdentifiers.daemon).plist")
        if fileManager.fileExists(atPath: targetURL.path) { return }

        guard let resourceURL = Bundle.main.url(forResource: BundleIdentifiers.daemon,
                                                withExtension: "plist",
                                                subdirectory: "LaunchDaemons") else {
            throw NSError(domain: "com.skynet.selfcontrol", code: 900, userInfo: [
                NSLocalizedDescriptionKey: "LaunchDaemon plist not found in app resources. Run scripts/package_app.sh to build a proper app bundle."
            ])
        }

        do {
            try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
            try fileManager.copyItem(at: resourceURL, to: targetURL)
        } catch {
            throw NSError(domain: "com.skynet.selfcontrol", code: 901, userInfo: [
                NSLocalizedDescriptionKey: "Failed to place LaunchDaemon plist in app bundle: \(error.localizedDescription). Run scripts/package_app.sh before signing."
            ])
        }
    }
}
