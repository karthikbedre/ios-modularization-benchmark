import DesignSystem
import DI
import Home
import HomeAPI
import NotificationsAPI
import SwiftUI

struct RootView: View {
    enum Tab: Hashable {
        case home, explore, wallet, inbox, profile
    }

    let container: Container
    let router: AppRouter
    @State private var tab = Tab.home
    @State private var unread = 0

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeFeature.makeScreen(container: container) { router.view(for: $0) }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(Tab.home)

            NavigationStack {
                ExploreScreen(router: router)
            }
            .tabItem { Label("Explore", systemImage: "square.grid.2x2") }
            .tag(Tab.explore)

            NavigationStack {
                router.view(for: .wallet)
            }
            .tabItem { Label("Wallet", systemImage: "creditcard") }
            .tag(Tab.wallet)

            NavigationStack {
                router.view(for: .inbox)
            }
            .tabItem { Label("Inbox", systemImage: "tray") }
            .badge(unread)
            .tag(Tab.inbox)

            NavigationStack {
                router.view(for: .profile)
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(Tab.profile)
        }
        .tint(Palette.accent)
        .task(id: tab) {
            unread = (try? await container.resolve((any NotificationsService).self).unreadCount()) ?? 0
        }
    }
}

private struct ExploreScreen: View {
    let router: AppRouter

    private let groups: [(String, [HomeSection])] = [
        ("Get around", [.transit, .parking]),
        ("Things to do", [.events, .dining, .library]),
        ("Your plans", [.agenda, .tickets, .reservations, .saved]),
        ("City services", [.reports]),
    ]

    var body: some View {
        List {
            if !SyntheticFeatures.entries.isEmpty {
                Section("More services") {
                    ForEach(SyntheticFeatures.entries, id: \.title) { entry in
                        NavigationLink(entry.title) { entry.screen(router.container) }
                    }
                }
            }
            ForEach(groups, id: \.0) { title, sections in
                Section(title) {
                    if title == "Get around" {
                        NavigationLink {
                            router.places
                        } label: {
                            Label("Places", systemImage: "map")
                        }
                    }
                    ForEach(sections, id: \.self) { section in
                        NavigationLink {
                            router.view(for: section)
                        } label: {
                            Label(section.title, systemImage: section.systemImage)
                        }
                    }
                }
            }
        }
        .navigationTitle("Explore")
        .toolbar {
            NavigationLink {
                router.view(for: .search)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Search")
        }
    }
}
