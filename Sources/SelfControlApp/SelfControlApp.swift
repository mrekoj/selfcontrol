import SwiftUI
import ServiceManagement
import SelfControlCore

@main
struct SelfControlApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var updater = UpdaterController()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, updater: updater)
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updater: UpdaterController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            daemonSection
            blockSection
            controlsSection
            EmergencyUnlockView(model: model)
            statusSection
        }
        .padding(24)
        .frame(minWidth: 520)
        .onAppear { model.refresh() }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SkyControl")
                .font(.largeTitle)
            Text("SwiftUI rewrite (macOS 13+, Apple silicon)")
                .foregroundStyle(.secondary)
            Text("App version \(SelfControlVersion.current)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var daemonSection: some View {
        GroupBox("Daemon") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Status: \(statusText(model.daemonStatus))")
                Text("Version: \(model.daemonVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("Install") { model.installDaemon() }
                    Button("Uninstall") { model.uninstallDaemon() }
                    Button("Refresh") { model.refresh() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var blockSection: some View {
        GroupBox("Block settings") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Minutes")
                    TextField("60", value: $model.minutes, formatter: NumberFormatter())
                        .frame(width: 80)
                    Toggle("Allowlist", isOn: $model.allowlist)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Blocklist (one per line)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $model.blocklistText)
                        .frame(minHeight: 120)
                        .border(Color.gray.opacity(0.3))
                }

                HStack(spacing: 16) {
                    Toggle("Common subdomains", isOn: $model.evaluateCommonSubdomains)
                    Toggle("Linked domains", isOn: $model.includeLinkedDomains)
                }

                HStack(spacing: 16) {
                    Toggle("Allow local networks", isOn: $model.allowLocalNetworks)
                    Toggle("Clear caches", isOn: $model.clearCaches)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Start Block") { model.startBlock() }
                    .buttonStyle(.borderedProminent)
                Button("Update Blocklist") { model.updateBlocklist() }
            }

            HStack(spacing: 8) {
                Text("Extend by minutes")
                TextField("15", value: $model.extendMinutes, formatter: NumberFormatter())
                    .frame(width: 80)
                Button("Extend") { model.extendBlock() }
                Button("Check for Updates") { updater.checkForUpdates() }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Block status: \(model.blockStatusText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let message = model.errorMessage {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    private func statusText(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: return "not registered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requires approval"
        case .notFound: return "not found"
        @unknown default: return "unknown"
        }
    }
}
