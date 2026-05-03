import SwiftUI
import Scaffolding

struct HomeView: View {
    @Environment(AppCoordinator.self) private var coordinator

    private let items = ["Mercury", "Venus", "Earth", "Mars", "Jupiter"]

    @State private var toast: String?

    var body: some View {
        List {
            Section {
                if let session = coordinator.session {
                    LabeledContent("Signed in as", value: session.username)
                    Button("Sign out", role: .destructive) {
                        coordinator.signOut()
                    }
                } else {
                    Button("Sign in") {
                        coordinator.startLoginFlow()
                    }
                }
            } header: {
                Text("Session")
            } footer: {
                Text("Classic coordinator pattern: result delivered via the `onComplete` callback embedded in the route definition.")
            }

            Section {
                ForEach(items, id: \.self) { item in
                    Button(item) {
                        coordinator.openDetail(id: item)
                    }
                }
            } header: {
                Text("Planets")
            } footer: {
                Text("Each tap calls `route(to: AppCoordinator.detail(id:))` — typed push, no `as!`.")
            }

            Section {
                Button("Open Settings (flow-sheet)") {
                    coordinator.openSettings { action in
                        toast = "Settings: \(action)"
                    }
                }
            } header: {
                Text("Modals")
            } footer: {
                Text("Settings is a flow-sheet — onDismiss fires reliably whether you tap Save or Cancel.")
            }
        }
        .navigationTitle("Scaffolding 3.0 Demo")
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        self.toast = nil
                    }
            }
        }
        .animation(.default, value: toast)
    }
}
