import Foundation
import SelfControlCore

@main
struct SelfControlDaemon {
    static func main() {
        // Placeholder daemon main loop; real XPC setup will be added in Phase 3.
        NSLog("selfcontrold starting (stub), version %@", SelfControlVersion.current)
        RunLoop.main.run()
    }
}
