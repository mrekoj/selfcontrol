import SwiftUI
import ServiceManagement
import SelfControlCore

@main
struct SelfControlApp: App {
    @StateObject private var installer = DaemonInstaller()

    var body: some Scene {
        WindowGroup {
            ContentView(installer: installer)
        }
    }
}

struct ContentView: View {
    @ObservedObject var installer: DaemonInstaller
    @State private var daemonVersion: String = "unknown"
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("SelfControl")
                .font(.largeTitle)
            Text("SwiftUI rewrite scaffold")
                .foregroundStyle(.secondary)
            Text("Version \(SelfControlVersion.current)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 8)

            Text("Daemon status: \(statusText(installer.state))")
            Text("Daemon version: \(daemonVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Install Daemon") {
                    runInstall()
                }
                Button("Uninstall Daemon") {
                    runUninstall()
                }
                Button("Check Version") {
                    fetchDaemonVersion()
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding(32)
        .frame(minWidth: 420)
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

    private func runInstall() {
        do {
            try installer.register()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runUninstall() {
        do {
            try installer.unregister()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchDaemonVersion() {
        let proxy = DaemonClient.shared.connect().remoteObjectProxyWithErrorHandler { error in
            errorMessage = error.localizedDescription
        } as? DaemonXPCProtocol

        proxy?.getVersion { version in
            daemonVersion = version
            errorMessage = nil
        }
    }
}
