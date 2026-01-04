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
        case "start":
            runStart(args: Array(args.dropFirst()))
        default:
            printUsage()
            exit(1)
        }
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

        let connection = DaemonClient.shared.connect()
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            fputs("Daemon connection failed: \(error)\n", stderr)
        } as? DaemonXPCProtocol

        guard let remote = proxy else {
            fputs("Unable to connect to daemon. Is selfcontrold installed and running?\n", stderr)
            exit(1)
        }

        let sema = DispatchSemaphore(value: 0)
        remote.startBlock(blocklist: blocklist, isAllowlist: allowlist, endDate: endDate, settings: settings, authorization: nil) { error in
            if let error {
                fputs("Start failed: \(error.localizedDescription)\n", stderr)
            } else {
                print("Block started until \(endDate)")
            }
            sema.signal()
        }

        _ = sema.wait(timeout: .now() + 30)
    }

    private static func printUsage() {
        print("""
selfcontrol-cli

Commands:
  version
  start --minutes <N> [--allowlist] (--block <host> | --blocklist <a,b,c>)
""")
    }
}
