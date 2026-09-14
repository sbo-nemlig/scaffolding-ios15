import SwiftUI
import Scaffolding

@Scaffoldable @Observable
final class AppCoordinator: @MainActor TabCoordinatable {
    var tabItems = TabItems<AppCoordinator>(tabs: [.planets, .favorites, .search])

    init() {
        // Identifiers belong on the coordinator, not the label view: the
        // framework writes them onto the rendered tab bar buttons, and they
        // stay stable while the visible label gets localized.
        setTabAccessibilityIdentifier("tab.planets", for: .planets)
        setTabAccessibilityIdentifier("tab.favorites", for: .favorites)
        // A button is found by its rendered label. When that is not the
        // title — here the label carries a custom accessibility label —
        // list what the button may read.
        setTabAccessibilityIdentifier(
            "tab.search",
            matchingLabels: ["Search", "Find a planet"],
            for: .search
        )
    }

    func planets() -> (any Coordinatable, some View) {
        (PlanetsCoordinator(), Label("Planets", systemImage: "globe"))
    }

    func favorites() -> (any Coordinatable, some View) {
        (FavoritesCoordinator(), Label("Favorites", systemImage: "star"))
    }

    func search() -> (any Coordinatable, some View, TabRole) {
        (
            SearchCoordinator(),
            Label("Search", systemImage: "magnifyingglass")
                .accessibilityLabel("Find a planet"),
            .search
        )
    }
}
