import Foundation
import SelfControlCore

@main
struct SelfControlDaemon {
    static func main() {
        let service = DaemonService()
        NSLog("selfcontrold starting, version %@", SelfControlVersion.current)
        service.start()
        RunLoop.main.run()
    }
}
