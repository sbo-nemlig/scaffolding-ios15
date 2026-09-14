//
//  TabBarAccessibilityIdentifierBridge.swift
//  Scaffolding
//
//  Applies tab accessibility identifiers to the rendered UIKit tab bar
//  buttons after render.
//

import SwiftUI
import os.log

// MARK: - Entries and label matching (platform-neutral, unit-tested)

/// One tab's accessibility identifier together with what is needed to
/// find its rendered button.
@available(iOS 18, macOS 15, *)
struct TabBarAccessibilityIdentifierEntry: Equatable, Sendable {
    /// Position of the tab in the coordinator's `tabs`. Used to pair the
    /// entry with the `UITabBarItem` at the same position when no
    /// `matchingLabels` were supplied.
    let tabIndex: Int
    let identifier: String
    /// Consumer-supplied labels. Empty means "derive from the rendered
    /// `UITabBarItem`".
    let matchingLabels: [String]
    /// The badge the tab currently carries, used to sanity-check the
    /// index pairing against the rendered item.
    let badge: String?

    /// Builds the entries for the given tabs. Tabs without an identifier
    /// are skipped; a hidden tab bar (custom bar) yields no entries at all,
    /// since there is no native button to identify.
    @MainActor
    static func entries(for tabs: [Destination], tabBarVisibility: Visibility) -> [TabBarAccessibilityIdentifierEntry] {
        guard tabBarVisibility != .hidden else { return [] }
        return tabs.enumerated().compactMap { index, tab in
            guard let identifier = tab.accessibilityIdentifier, !identifier.isEmpty else { return nil }
            return TabBarAccessibilityIdentifierEntry(
                tabIndex: index,
                identifier: identifier,
                matchingLabels: tab.accessibilityMatchingLabels,
                badge: tab.badge
            )
        }
    }
}

/// Matches rendered tab bar button labels against candidate labels.
///
/// An exact match (trimmed, case-insensitive) outranks a containment
/// match in either direction; the latter tolerates rendered labels that
/// append badge or state text to the title.
@available(iOS 18, macOS 15, *)
enum TabBarAccessibilityLabelMatching {
    enum Strength: Int, Comparable {
        case contains = 1
        case exact = 2

        static func < (lhs: Strength, rhs: Strength) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static func strength(renderedLabel: String, candidate: String) -> Strength? {
        let rendered = renderedLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rendered.isEmpty, !candidate.isEmpty else { return nil }

        if rendered.caseInsensitiveCompare(candidate) == .orderedSame {
            return .exact
        }
        if rendered.localizedCaseInsensitiveContains(candidate)
            || candidate.localizedCaseInsensitiveContains(rendered) {
            return .contains
        }
        return nil
    }

    /// Picks the candidate set that best matches the rendered labels of one
    /// button. Returns `nil` when nothing matches or when the best match is
    /// ambiguous (two candidate sets tie), so an identifier is never written
    /// onto a button it might not belong to.
    static func bestCandidate(renderedLabels: [String], candidates: [[String]]) -> Int? {
        var best: (index: Int, strength: Strength)?
        var tie = false

        for (index, labels) in candidates.enumerated() {
            let strength = labels
                .flatMap { candidate in renderedLabels.compactMap { self.strength(renderedLabel: $0, candidate: candidate) } }
                .max()
            guard let strength else { continue }

            if let current = best {
                if strength > current.strength {
                    best = (index, strength)
                    tie = false
                } else if strength == current.strength {
                    tie = true
                }
            } else {
                best = (index, strength)
            }
        }

        guard let best, !tie else { return nil }
        return best.index
    }
}

// MARK: - UIKit bridge

#if os(iOS) && canImport(UIKit)
import UIKit

/// Invisible helper that observes the coordinator's tabs from its own view
/// node and feeds the resolved identifiers to
/// ``TabBarAccessibilityIdentifierBridge``. Reading `tabs` here (rather
/// than in the `TabView` body) makes SwiftUI re-run the bridge whenever an
/// identifier, label set, or badge changes.
@available(iOS 18, macOS 15, *)
struct TabBarAccessibilityIdentifierSync: View {
    let coordinator: any TabCoordinatable

    var body: some View {
        let items = coordinator.anyTabItems
        TabBarAccessibilityIdentifierBridge(
            entries: TabBarAccessibilityIdentifierEntry.entries(for: items.tabs, tabBarVisibility: items.tabBarVisibility),
            tabCount: items.tabs.count
        )
    }
}

/// Writes each tab's accessibility identifier onto the matching rendered
/// `UITabBar` button.
///
/// SwiftUI forwards a `Tab`'s identifier to its `UITabBarItem` only once
/// the accessibility system first queries the app, and the buttons copy
/// the item's identifier only when they are constructed — so on a cold
/// launch UI tests never see it. Writing the identifier onto the buttons
/// themselves is what surfaces it. The bridge runs after every SwiftUI
/// update, whenever its host view (re)enters a window, on trait changes,
/// and along a short retry ladder after each of those, so a bar rebuilt by
/// UIKit (a badge change recreates the `Tab` entry) picks the identifiers
/// up again.
@available(iOS 18, macOS 15, *)
@MainActor
private struct TabBarAccessibilityIdentifierBridge: UIViewControllerRepresentable {
    let entries: [TabBarAccessibilityIdentifierEntry]
    let tabCount: Int

    func makeUIViewController(context: Context) -> BridgeController {
        let controller = BridgeController()
        controller.onAttach = { [weak coordinator = context.coordinator] in
            coordinator?.scheduleApply(reason: "attach")
        }
        context.coordinator.hostController = controller
        context.coordinator.update(entries: entries, tabCount: tabCount)
        return controller
    }

    func updateUIViewController(_ uiViewController: BridgeController, context: Context) {
        context.coordinator.hostController = uiViewController
        context.coordinator.update(entries: entries, tabCount: tabCount)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Hidden host whose view reports window attachment and trait changes.
    final class BridgeController: UIViewController {
        var onAttach: (() -> Void)?

        override func loadView() {
            let view = BridgeView()
            view.isHidden = true
            view.isUserInteractionEnabled = false
            view.onDidMoveToWindow = { [weak self] in self?.onAttach?() }
            self.view = view
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            registerForTraitChanges([
                UITraitHorizontalSizeClass.self,
                UITraitVerticalSizeClass.self,
                UITraitPreferredContentSizeCategory.self,
                UITraitLayoutDirection.self,
            ]) { (controller: BridgeController, _) in
                controller.onAttach?()
            }
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            if parent != nil { onAttach?() }
        }
    }

    final class BridgeView: UIView {
        var onDidMoveToWindow: (() -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { onDidMoveToWindow?() }
        }
    }

    @MainActor
    final class Coordinator {
        weak var hostController: UIViewController?

        private var entries: [TabBarAccessibilityIdentifierEntry] = []
        private var tabCount = 0
        private var applyTask: Task<Void, Never>?
        /// Identifiers this bridge wrote in the previous pass, cleared before
        /// every re-write so removed or renamed identifiers do not linger.
        private var previouslyManagedIdentifiers: Set<String> = []

        /// Delays between attempts after a trigger. UIKit rebuilds the tab
        /// bar buttons after SwiftUI's update has finished, so the first
        /// attempts of a pass often run before the new buttons exist.
        private static let retryDelays: [UInt64] = [0, 50, 200, 500, 1_000, 2_000]

        deinit {
            applyTask?.cancel()
        }

        func update(entries: [TabBarAccessibilityIdentifierEntry], tabCount: Int) {
            self.entries = entries
            self.tabCount = tabCount
            scheduleApply(reason: "update")
        }

        func scheduleApply(reason: String) {
            applyTask?.cancel()
            applyTask = Task { @MainActor [weak self] in
                var lastOutcome: Outcome = .noTabBar
                for (attempt, delay) in Self.retryDelays.enumerated() {
                    if attempt > 0 {
                        try? await Task.sleep(nanoseconds: delay * 1_000_000)
                    }
                    guard !Task.isCancelled, let self else { return }
                    lastOutcome = self.apply()
                    if case .applied(let missing) = lastOutcome, missing.isEmpty { return }
                }
                guard !Task.isCancelled, let self else { return }
                self.reportFailure(lastOutcome, reason: reason)
            }
        }

        enum Outcome {
            case noTabBar
            case noControls
            case applied(missing: [String])
        }

        /// One pass: find the tab bar, pair entries with buttons, write the
        /// identifiers. Idempotent.
        func apply() -> Outcome {
            guard let hostController,
                  let tabBarController = hostController.nearestTabBarController() else {
                return .noTabBar
            }

            let controls = tabBarController.tabBar.descendantControls()
            guard !controls.isEmpty else { return .noControls }

            clearPreviouslyManagedIdentifiers(from: controls)
            previouslyManagedIdentifiers = []
            guard !entries.isEmpty else { return .applied(missing: []) }

            let candidates = entries.map { candidateLabels(for: $0, in: tabBarController) }

            var applied: Set<String> = []
            for control in controls {
                let renderedLabels = [control.accessibilityLabel, control.firstDescendantLabelText()].compactMap { $0 }
                guard let index = TabBarAccessibilityLabelMatching.bestCandidate(
                    renderedLabels: renderedLabels,
                    candidates: candidates
                ) else { continue }

                let identifier = entries[index].identifier
                control.accessibilityIdentifier = identifier
                applied.insert(identifier)
            }

            previouslyManagedIdentifiers = applied
            let missing = entries.map(\.identifier).filter { !applied.contains($0) }
            return .applied(missing: missing)
        }

        /// The labels a button for this entry may carry: the consumer's
        /// `matchingLabels`, or — when none were given — the title and
        /// accessibility label of the `UITabBarItem` at the same position.
        ///
        /// SwiftUI creates the tab bar controller's `viewControllers` (and
        /// therefore `tabBar.items`) in declaration order, even where the
        /// bar renders a tab elsewhere (a `.search` role on iOS 26). The
        /// pairing is still checked: an item that already carries a
        /// different identifier or badge than the entry is not trusted.
        private func candidateLabels(
            for entry: TabBarAccessibilityIdentifierEntry,
            in tabBarController: UITabBarController
        ) -> [String] {
            if !entry.matchingLabels.isEmpty {
                return entry.matchingLabels
            }

            let items: [UITabBarItem] = tabBarController.viewControllers?.compactMap { $0.tabBarItem }
                ?? tabBarController.tabBar.items
                ?? []
            guard items.count == tabCount, entry.tabIndex < items.count else { return [] }
            let item = items[entry.tabIndex]

            if let itemIdentifier = item.accessibilityIdentifier, !itemIdentifier.isEmpty,
               itemIdentifier != entry.identifier {
                return []
            }
            if let badge = item.badgeValue, let expected = entry.badge, badge != expected {
                return []
            }

            let title: String? = item.title
            let accessibilityLabel: String? = item.accessibilityLabel
            return [title, accessibilityLabel].compactMap { $0 }.filter { !$0.isEmpty }
        }

        private func clearPreviouslyManagedIdentifiers(from controls: [UIControl]) {
            guard !previouslyManagedIdentifiers.isEmpty else { return }
            for control in controls where previouslyManagedIdentifiers.contains(control.accessibilityIdentifier ?? "") {
                control.accessibilityIdentifier = nil
            }
        }

        private func reportFailure(_ outcome: Outcome, reason: String) {
#if DEBUG
            guard !entries.isEmpty, hostController?.view.window != nil else { return }
            let logger = Logger(subsystem: "Scaffolding", category: "TabBarAccessibility")
            switch outcome {
            case .noTabBar:
                logger.error("Scaffolding: no UITabBarController found to apply tab accessibility identifiers to (trigger: \(reason, privacy: .public)).")
            case .noControls:
                logger.error("Scaffolding: the tab bar has no buttons yet; tab accessibility identifiers were not applied (trigger: \(reason, privacy: .public)).")
            case .applied(let missing):
                guard !missing.isEmpty else { return }
                logger.error("Scaffolding: tab accessibility identifier(s) \(missing.joined(separator: ", "), privacy: .public) matched no tab bar button (trigger: \(reason, privacy: .public)). Buttons are matched by their rendered label; pass the label(s) the tab renders via setTabAccessibilityIdentifier(_:matchingLabels:for:).")
            }
#endif
        }
    }
}

@available(iOS 18, macOS 15, *)
private extension UIViewController {
    /// The `UITabBarController` closest to this controller: first the one
    /// hosted alongside it (the bridge sits next to the `TabView` inside the
    /// same hosting controller), walking outwards through the parents, then
    /// the window's root as a last resort.
    func nearestTabBarController() -> UITabBarController? {
        var current: UIViewController? = self
        while let controller = current {
            if let tabBarController = controller.firstTabBarController(excluding: self) {
                return tabBarController
            }
            current = controller.parent
        }
        return view.window?.rootViewController?.firstTabBarController(excluding: self)
    }

    func firstTabBarController(excluding excluded: UIViewController) -> UITabBarController? {
        if let tabBarController = self as? UITabBarController {
            return tabBarController
        }
        for child in children where child !== excluded {
            if let tabBarController = child.firstTabBarController(excluding: excluded) {
                return tabBarController
            }
        }
        if let presentedViewController,
           let tabBarController = presentedViewController.firstTabBarController(excluding: excluded) {
            return tabBarController
        }
        return nil
    }
}

@available(iOS 18, macOS 15, *)
private extension UIView {
    func descendantControls() -> [UIControl] {
        var controls: [UIControl] = []
        for subview in subviews {
            if let control = subview as? UIControl {
                controls.append(control)
            } else {
                controls.append(contentsOf: subview.descendantControls())
            }
        }
        return controls
    }

    func firstDescendantLabelText() -> String? {
        for subview in subviews {
            if let label = subview as? UILabel, let text = label.text, !text.isEmpty {
                return text
            }
            if let text = subview.firstDescendantLabelText() {
                return text
            }
        }
        return nil
    }
}
#else
/// No-op on platforms without a UIKit tab bar.
@available(iOS 18, macOS 15, *)
struct TabBarAccessibilityIdentifierSync: View {
    let coordinator: any TabCoordinatable

    var body: some View {
        EmptyView()
    }
}
#endif
