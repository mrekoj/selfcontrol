import Foundation
import ServiceManagement
import SelfControlCore

@MainActor
final class AppModel: ObservableObject {
    @Published var minutes: Int = 60
    @Published var allowlist: Bool = false
    @Published var blocklistText: String = ""

    @Published var daemonStatus: SMAppService.Status = .notRegistered
    @Published var daemonVersion: String = "unknown"
    @Published var blockStatusText: String = "unknown"
    @Published var errorMessage: String?

    @Published var evaluateCommonSubdomains: Bool = true
    @Published var includeLinkedDomains: Bool = true
    @Published var allowLocalNetworks: Bool = true
    @Published var clearCaches: Bool = true

    private let installer = DaemonInstaller()

    func refresh() {
        installer.refreshStatus()
        daemonStatus = installer.state
        fetchDaemonVersion()
        refreshBlockStatus()
    }

    func installDaemon() {
        do {
            try installer.register()
            daemonStatus = installer.state
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uninstallDaemon() {
        do {
            try installer.unregister()
            daemonStatus = installer.state
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startBlock() {
        let rawLines = blocklistText.components(separatedBy: .newlines)
        var cleaned: [String] = []
        for line in rawLines {
            cleaned.append(contentsOf: BlocklistCleaner.cleanEntry(line))
        }

        guard minutes > 0 else {
            errorMessage = "Minutes must be greater than 0."
            return
        }
        if cleaned.isEmpty && !allowlist {
            errorMessage = "Blocklist cannot be empty unless allowlist is enabled."
            return
        }

        let endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let settings = BlockSettings(
            evaluateCommonSubdomains: evaluateCommonSubdomains,
            includeLinkedDomains: includeLinkedDomains,
            blockSoundShouldPlay: false,
            blockSound: 5,
            clearCaches: clearCaches,
            allowLocalNetworks: allowLocalNetworks,
            enableErrorReporting: false
        )

        let proxy = DaemonClient.shared.connect().remoteObjectProxyWithErrorHandler { error in
            self.errorMessage = error.localizedDescription
        } as? DaemonXPCProtocol

        guard let remote = proxy else {
            errorMessage = "Unable to connect to daemon. Is it installed and approved?"
            return
        }

        remote.startBlock(blocklist: cleaned, isAllowlist: allowlist, endDate: endDate, settings: settings, authorization: nil) { error in
            if let error {
                self.errorMessage = error.localizedDescription
            } else {
                self.errorMessage = nil
                self.refreshBlockStatus()
            }
        }
    }

    func fetchDaemonVersion() {
        let proxy = DaemonClient.shared.connect().remoteObjectProxyWithErrorHandler { error in
            self.errorMessage = error.localizedDescription
        } as? DaemonXPCProtocol

        proxy?.getVersion { version in
            self.daemonVersion = version
        }
    }

    private func refreshBlockStatus() {
        let serial = SystemInfo.serialNumber() ?? "UNKNOWN"
        let url = SettingsPaths.defaultURL(serialNumber: serial)
        let store = SettingsStore(url: url)
        if let settings = try? store.load() {
            if BlockState.isRunning(settings: settings) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                blockStatusText = "running until \(formatter.string(from: settings.blockEndDate))"
            } else {
                blockStatusText = "not running"
            }
        } else {
            blockStatusText = "unknown"
        }
    }
}
