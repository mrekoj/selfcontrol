import SwiftUI
import SelfControlCore

struct EmergencyUnlockView: View {
    @ObservedObject var model: AppModel
    @State private var reason: String = ""

    var body: some View {
        GroupBox("Emergency unlock") {
            VStack(alignment: .leading, spacing: 8) {
                Text("This will immediately clear the active block.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Reason (required)", text: $reason)

                Button("Clear Block") {
                    let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else {
                        model.errorMessage = "Please provide a reason for emergency unlock."
                        return
                    }
                    model.clearBlock(reason: trimmed)
                }
            }
        }
    }
}
