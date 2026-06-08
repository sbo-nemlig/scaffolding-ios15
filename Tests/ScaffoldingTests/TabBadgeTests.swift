//
//  TabBadgeTests.swift
//  ScaffoldingTests
//
//  Tests for tab badge state on TabItems.
//

import Testing
@testable import Scaffolding

// MARK: - Tab Badges

@MainActor
@Suite("Tab badges")
struct TabBadgeTests {

    @Test("Setting a positive badge stores it without changing selection")
    func positiveBadgeStoresWithoutChangingSelection() {
        guard #available(iOS 18, macOS 15, *) else { return }
        let tab = MainTabCoordinator()
        _ = tab.anyTabItems

        let selected = tab.tabItems.selectedTab
        let tabIDs = tab.tabItems.tabs.map(\.id)
        let homeID = tabIDs[0]

        tab.tabItems.setBadge(3, for: homeID)

        #expect(tab.tabItems.badge(for: homeID) == 3)
        #expect(tab.tabItems.selectedTab == selected)
        #expect(tab.tabItems.tabs.map(\.id) == tabIDs)
    }

    @Test("Updating a positive badge replaces the stored value")
    func positiveBadgeUpdateReplacesValue() {
        guard #available(iOS 18, macOS 15, *) else { return }
        let tab = MainTabCoordinator()
        _ = tab.anyTabItems

        let homeID = tab.tabItems.tabs[0].id
        tab.tabItems.setBadge(3, for: homeID)
        tab.tabItems.setBadge(9, for: homeID)

        #expect(tab.tabItems.badge(for: homeID) == 9)
    }

    @Test("Nil clears an existing badge")
    func nilClearsExistingBadge() {
        guard #available(iOS 18, macOS 15, *) else { return }
        let tab = MainTabCoordinator()
        _ = tab.anyTabItems

        let selected = tab.tabItems.selectedTab
        let tabIDs = tab.tabItems.tabs.map(\.id)
        let homeID = tab.tabItems.tabs[0].id
        tab.tabItems.setBadge(3, for: homeID)
        tab.tabItems.setBadge(nil, for: homeID)

        #expect(tab.tabItems.badge(for: homeID) == nil)
        #expect(tab.tabItems.selectedTab == selected)
        #expect(tab.tabItems.tabs.map(\.id) == tabIDs)
    }

    @Test("Zero clears an existing badge")
    func zeroClearsExistingBadge() {
        guard #available(iOS 18, macOS 15, *) else { return }
        let tab = MainTabCoordinator()
        _ = tab.anyTabItems

        let selected = tab.tabItems.selectedTab
        let tabIDs = tab.tabItems.tabs.map(\.id)
        let homeID = tab.tabItems.tabs[0].id
        tab.tabItems.setBadge(3, for: homeID)
        tab.tabItems.setBadge(0, for: homeID)

        #expect(tab.tabItems.badge(for: homeID) == nil)
        #expect(tab.tabItems.selectedTab == selected)
        #expect(tab.tabItems.tabs.map(\.id) == tabIDs)
    }

    @Test("Negative values clear an existing badge")
    func negativeClearsExistingBadge() {
        guard #available(iOS 18, macOS 15, *) else { return }
        let tab = MainTabCoordinator()
        _ = tab.anyTabItems

        let selected = tab.tabItems.selectedTab
        let tabIDs = tab.tabItems.tabs.map(\.id)
        let homeID = tab.tabItems.tabs[0].id
        tab.tabItems.setBadge(3, for: homeID)
        tab.tabItems.setBadge(-1, for: homeID)

        #expect(tab.tabItems.badge(for: homeID) == nil)
        #expect(tab.tabItems.selectedTab == selected)
        #expect(tab.tabItems.tabs.map(\.id) == tabIDs)
    }

    @Test("Badges are independent per tab id")
    func badgesAreIndependentPerTabID() {
        guard #available(iOS 18, macOS 15, *) else { return }
        let tab = MainTabCoordinator()
        _ = tab.anyTabItems

        let homeID = tab.tabItems.tabs[0].id
        let profileID = tab.tabItems.tabs[1].id

        tab.tabItems.setBadge(3, for: homeID)
        tab.tabItems.setBadge(7, for: profileID)
        tab.tabItems.setBadge(nil, for: homeID)

        #expect(tab.tabItems.badge(for: homeID) == nil)
        #expect(tab.tabItems.badge(for: profileID) == 7)
    }

    @Test("Setting a badge by meta preserves tabs and selection")
    func metaBadgePreservesTabsAndSelection() {
        guard #available(iOS 18, macOS 15, *) else { return }
        let tab = MainTabCoordinator()
        _ = tab.anyTabItems

        let selected = tab.tabItems.selectedTab
        let tabIDs = tab.tabItems.tabs.map(\.id)
        let profileID = tabIDs[1]

        tab.tabItems.setBadge(5, forFirst: .profile)

        #expect(tab.tabItems.badge(for: profileID) == 5)
        #expect(tab.tabItems.selectedTab == selected)
        #expect(tab.tabItems.tabs.map(\.id) == tabIDs)
    }
}
