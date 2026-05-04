import SwiftUI
import Scaffolding

@main
struct ScaffoldingDemoApp: App {
    var body: some Scene {
        WindowGroup {
            coordinator.view
        }
    }
}

@available(iOS 17, *)
private struct AppRootView: View {
    @State private var coordinator = AppCoordinator()
    var body: some View { coordinator.view() }
}
