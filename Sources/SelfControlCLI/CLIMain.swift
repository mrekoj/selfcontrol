import Foundation
import SelfControlCore

@main
struct SelfControlCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            printUsage()
            exit(1)
        }

        switch command {
        case "version":
            print(SelfControlVersion.current)
        case "status":
            runStatus()
        case "unlock":
            runUnlock(args: Array(args.dropFirst()))
        case "start":
            runStart(args: Array(args.dropFirst()))
        case "update":
            runUpdate(args: Array(args.dropFirst()))
        case "extend":
            runExtend(args: Array(args.dropFirst()))
        default:
            printUsage()
            exit(1)
        }
    }

    private static func runStatus() {
        let proxy = DaemonClient.shared.connect().remoteObjectProxyWithErrorHandler { error in
            fputs("Daemon connection failed: \(error)\n", stderr)
        } as? DaemonXPCProtocol

        guard let remote = proxy else {
            fputs("Unable to connect to daemon. Is selfcontrold installed and running?\n", stderr)
            exit(1)
        }

        let sema = DispatchSemaphore(value: 0)
        remote.getVersion { version in
            print("daemon version: \(version)")
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 5)
    }

    private static func runStart(args: [String]) {
        var minutes: Int?
        var allowlist = false
        var blocklist: [String] = []

        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--minutes":
                i += 1
                if i < args.count { minutes = Int(args[i]) }
            case "--allowlist":
                allowlist = true
            case "--block":
                i += 1
                if i < args.count { blocklist.append(args[i]) }
            case "--blocklist":
                i += 1
                if i < args.count {
                    blocklist.append(contentsOf: args[i].split(separator: ",").map(String.init))
                }
            default:
                break
            }
            i += 1
        }

        guard let mins = minutes, mins > 0, !blocklist.isEmpty || allowlist else {
            printUsage()
            exit(1)
        }

        let endDate = Date().addingTimeInterval(TimeInterval(mins * 60))
        let settings = BlockSettings(from: Settings.defaults)
        guard let authData = authorizationData(for: .startBlock) else { return }

        let connection = DaemonClient.shared.connect()
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            fputs("Daemon connection failed: \(error)\n", stderr)
        } as? DaemonXPCProtocol

        guard let remote = proxy else {
            fputs("Unable to connect to daemon. Is selfcontrold installed and running?\n", stderr)
            exit(1)
        }

        let sema = DispatchSemaphore(value: 0)
        remote.startBlock(blocklist: blocklist, isAllowlist: allowlist, endDate: endDate, settings: settings, authorization: authData) { error in
            if let error {
                fputs("Start failed: \(error.localizedDescription)\n", stderr)
            } else {
                print("Block started until \(endDate)")
            }
            sema.signal()
        }

        _ = sema.wait(timeout: .now() + 30)
    }

    private static func runUpdate(args: [String]) {
        var blocklist: [String] = []
        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--block":
                i += 1
                if i < args.count { blocklist.append(args[i]) }
            case "--blocklist":
                i += 1
                if i < args.count {
                    blocklist.append(contentsOf: args[i].split(separator: ",").map(String.init))
                }
            default:
                break
            }
            i += 1
        }

        guard !blocklist.isEmpty else {
            fputs("Update requires --block or --blocklist\n", stderr)
            exit(1)
        }

        guard let authData = authorizationData(for: .updateBlocklist) else { return }

        let proxy = DaemonClient.shared.connect().remoteObjectProxyWithErrorHandler { error in
            fputs("Daemon connection failed: \(error)\n", stderr)
        } as? DaemonXPCProtocol

        guard let remote = proxy else {
            fputs("Unable to connect to daemon. Is selfcontrold installed and running?\n", stderr)
            exit(1)
        }

        let sema = DispatchSemaphore(value: 0)
        remote.updateBlocklist(blocklist, authorization: authData) { error in
            if let error {
                fputs("Update failed: \(error.localizedDescription)\n", stderr)
            } else {
                print("Blocklist updated")
            }
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 30)
    }

    private static func runExtend(args: [String]) {
        var minutes: Int?
        if let idx = args.firstIndex(of: "--minutes"), idx + 1 < args.count {
            minutes = Int(args[idx + 1])
        }
        guard let mins = minutes, mins > 0 else {
            fputs("Extend requires --minutes <N>\n", stderr)
            exit(1)
        }

        guard let authData = authorizationData(for: .updateBlockEndDate) else { return }

        let serial = SystemInfo.serialNumber() ?? "UNKNOWN"
        let url = SettingsPaths.defaultURL(serialNumber: serial)
        let store = SettingsStore(url: url)
        let current = (try? store.load()) ?? Settings.defaults
        let baseDate = max(current.blockEndDate, Date())
        let newEndDate = baseDate.addingTimeInterval(TimeInterval(mins * 60))

        let proxy = DaemonClient.shared.connect().remoteObjectProxyWithErrorHandler { error in
            fputs("Daemon connection failed: \(error)\n", stderr)
        } as? DaemonXPCProtocol

        guard let remote = proxy else {
            fputs("Unable to connect to daemon. Is selfcontrold installed and running?\n", stderr)
            exit(1)
        }

        let sema = DispatchSemaphore(value: 0)
        remote.updateBlockEndDate(newEndDate, authorization: authData) { error in
            if let error {
                fputs("Extend failed: \(error.localizedDescription)\n", stderr)
            } else {
                print("Block extended until \(newEndDate)")
            }
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 30)
    }

    private static func runUnlock(args: [String]) {
        var reason = ""
        if let idx = args.firstIndex(of: "--reason"), idx + 1 < args.count {
            reason = args[idx + 1]
        }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            fputs("Unlock requires --reason\n", stderr)
            exit(1)
        }

        let proxy = DaemonClient.shared.connect().remoteObjectProxyWithErrorHandler { error in
            fputs("Daemon connection failed: \(error)\n", stderr)
        } as? DaemonXPCProtocol

        guard let remote = proxy else {
            fputs("Unable to connect to daemon. Is selfcontrold installed and running?\n", stderr)
            exit(1)
        }

        let sema = DispatchSemaphore(value: 0)
        guard let authData = authorizationData(for: .clearBlock) else { return }
        remote.clearBlock(reason: trimmed, authorization: authData) { error in
            if let error {
                fputs("Unlock failed: \(error.localizedDescription)\n", stderr)
            } else {
                print("Block cleared")
            }
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 30)
    }

    private static func authorizationData(for command: AuthCommand) -> Data? {
        do {
            return try AuthorizationManager.authorizationData(for: command)
        } catch {
            fputs("Authorization failed: \(error.localizedDescription)\n", stderr)
            return nil
        }
    }

    private static func printUsage() {
        print("""
selfcontrol-cli

Commands:
  version
  status
  start --minutes <N> [--allowlist] (--block <host> | --blocklist <a,b,c>)
  update --block <host> | --blocklist <a,b,c>
  extend --minutes <N>
  unlock --reason <text>
""")
    }
}
