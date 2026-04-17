import SwiftUI
import Scaffolding

@main
struct ScaffoldingDemoApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 17, *) {
                AppRootView()
            } else {
                Text("Requires iOS 17 or later.")
            }
        }
    }
}

@available(iOS 17, *)
private struct AppRootView: View {
    @State private var coordinator = AppCoordinator()
    var body: some View { coordinator.view() }
}
