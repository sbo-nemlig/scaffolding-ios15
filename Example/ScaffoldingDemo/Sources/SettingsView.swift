import SwiftUI
import Scaffolding

@available(iOS 17, *)
struct SettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator

    @State private var notificationsEnabled = true
    @State private var displayName: String = ""

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $displayName)
            }
            Section("Preferences") {
                Toggle("Notifications", isOn: $notificationsEnabled)
            }
            Section {
                Button("Save") {
                    coordinator.lastSettingsAction = "saved"
                    coordinator.dismissCoordinator()
                }
                Button("Cancel", role: .cancel) {
                    coordinator.lastSettingsAction = "cancelled"
                    coordinator.dismissCoordinator()
                }
            } footer: {
                Text("Both Save and Cancel invoke `dismissCoordinator()` — the parent's `onDismiss` callback fires exactly once thanks to the resolution gate.")
            }
        }
    }
}
