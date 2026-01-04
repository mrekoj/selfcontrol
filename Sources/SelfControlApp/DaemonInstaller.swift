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
        try ensureAppInstalledLocation()
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
        if fileManager.fileExists(atPath: targetURL.path) {
            try validateDaemonPlist(at: targetURL)
            return
        }

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
            try validateDaemonPlist(at: targetURL)
        } catch {
            throw NSError(domain: "com.skynet.selfcontrol", code: 901, userInfo: [
                NSLocalizedDescriptionKey: "Failed to place LaunchDaemon plist in app bundle: \(error.localizedDescription). Run scripts/package_app.sh before signing."
            ])
        }
    }

    private func ensureAppInstalledLocation() throws {
        let appPath = Bundle.main.bundleURL.path
        if !appPath.hasPrefix("/Applications/") {
            throw NSError(domain: "com.skynet.selfcontrol", code: 902, userInfo: [
                NSLocalizedDescriptionKey: "Install the app in /Applications before installing the daemon (macOS requires this for LaunchDaemons)."
            ])
        }
    }

    private func validateDaemonPlist(at url: URL) throws {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = plist as? [String: Any] else { return }
        guard let args = dict["ProgramArguments"] as? [String], let first = args.first else {
            throw NSError(domain: "com.skynet.selfcontrol", code: 903, userInfo: [
                NSLocalizedDescriptionKey: "LaunchDaemon plist is missing ProgramArguments. Rebuild with scripts/package_app.sh and reinstall."
            ])
        }
        if !first.hasPrefix("/") {
            throw NSError(domain: "com.skynet.selfcontrol", code: 904, userInfo: [
                NSLocalizedDescriptionKey: "LaunchDaemon plist uses a relative ProgramArguments path. Rebuild with scripts/package_app.sh and reinstall from /Applications."
            ])
        }
    }
}
