import SwiftUI
import SelfControlCore

@main
struct SelfControlApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("SelfControl")
                .font(.largeTitle)
            Text("SwiftUI rewrite scaffold")
                .foregroundStyle(.secondary)
            Text("Version \(SelfControlVersion.current)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}
