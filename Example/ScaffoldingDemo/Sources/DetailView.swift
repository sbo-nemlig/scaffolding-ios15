import SwiftUI
import Scaffolding

@available(iOS 17, *)
struct DetailView: View {
    @Environment(AppCoordinator.self) private var coordinator

    let id: String

    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 24) {
            Text(id)
                .font(.largeTitle.bold())

            Text("This is the detail screen for \(id).")
                .foregroundStyle(.secondary)

            Button("Delete (view-sheet boundary)", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .buttonStyle(.bordered)

            Button("Pop") {
                coordinator.pop()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle(id)
        // Native SwiftUI alert — Scaffolding intentionally does NOT
        // own ephemeral view-level confirmations. The library handles
        // navigation flows; alerts/popovers/share-sheets stay here.
        .alert("Delete \(id)?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) { coordinator.pop() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This is a SwiftUI view-sheet — not a Scaffolding flow.")
        }
    }
}
