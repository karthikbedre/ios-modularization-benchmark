import DesignSystem
import EventsAPI
import HomeAPI
import SwiftUI

/// Builds the screen for a section. Supplied by the app, which is the only place that knows every feature.
public typealias HomeRouter = @MainActor (HomeSection) -> AnyView

struct HomeScreen: View {
    @State private var viewModel: HomeViewModel
    private let events: EventsEntryPoints
    private let route: HomeRouter

    init(service: any HomeService, events: EventsEntryPoints, route: @escaping HomeRouter) {
        _viewModel = State(initialValue: HomeViewModel(service: service))
        self.events = events
        self.route = route
    }

    var body: some View {
        AsyncContentView(state: viewModel.state, retry: viewModel.load) { dashboard in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    Text(dashboard.greeting)
                        .font(.title2.weight(.semibold))
                        .padding(.horizontal, Spacing.medium)
                    QuickActions()
                    if !dashboard.upNext.isEmpty {
                        UpNextSection(items: dashboard.upNext)
                    }
                    if !dashboard.featuredEvents.isEmpty {
                        FeaturedSection(events: dashboard.featuredEvents)
                    }
                    ServiceGrid(cards: dashboard.cards)
                }
                .padding(.vertical, Spacing.medium)
            }
            .refreshable { await viewModel.load() }
        }
        .navigationTitle("Civitas")
        .toolbar {
            NavigationLink(value: HomeSection.search) {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Search")
            NavigationLink(value: HomeSection.inbox) {
                Image(systemName: (viewModel.state.value?.unreadCount ?? 0) > 0 ? "bell.badge" : "bell")
            }
            .accessibilityLabel("Inbox")
        }
        .navigationDestination(for: HomeSection.self) { section in
            route(section)
        }
        .navigationDestination(for: FeaturedEvent.self) { event in
            events.detail(event.id)
        }
        .task { await viewModel.load() }
    }
}

private struct QuickActions: View {
    private let actions: [(HomeSection, String)] = [
        (.parking, "Park"), (.transit, "Ride"), (.dining, "Eat"), (.reports, "Report"), (.library, "Borrow"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.medium) {
                ForEach(actions, id: \.0) { section, label in
                    NavigationLink(value: section) {
                        VStack(spacing: Spacing.small) {
                            Image(systemName: section.systemImage)
                                .font(.title3)
                                .frame(width: 52, height: 52)
                                .background(Palette.accent.opacity(0.15), in: Circle())
                                .foregroundStyle(Palette.accent)
                            Text(label).font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.medium)
        }
    }
}

private struct UpNextSection: View {
    let items: [UpNextItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small * 2) {
            NavigationLink(value: HomeSection.agenda) {
                HStack {
                    Text("Up next").font(.headline)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            ForEach(items) { item in
                HStack(spacing: Spacing.medium) {
                    VStack(spacing: 0) {
                        Text(item.start, format: .dateTime.weekday(.abbreviated))
                            .font(.caption2.weight(.semibold))
                            .textCase(.uppercase)
                        Text(item.start, format: .dateTime.day())
                            .font(.headline)
                    }
                    .frame(width: 40)
                    .foregroundStyle(Palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                        Text([item.start.formatted(date: .omitted, time: .shortened), item.location].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(Spacing.medium)
                .background(Palette.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
            }
        }
        .padding(.horizontal, Spacing.medium)
    }
}

private struct FeaturedSection: View {
    let events: [FeaturedEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small * 2) {
            NavigationLink(value: HomeSection.events) {
                HStack {
                    Text("Happening soon").font(.headline)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.medium)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.medium) {
                    ForEach(events) { event in
                        NavigationLink(value: event) {
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Spacer()
                                Text(event.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text("\(event.start.formatted(.dateTime.weekday().hour().minute())) · \(event.venueName)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                            }
                            .padding(Spacing.medium)
                            .frame(width: 240, height: 130, alignment: .leading)
                            .background(
                                LinearGradient(colors: [Palette.accent, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: Radius.card)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.medium)
            }
        }
    }
}

private struct ServiceGrid: View {
    let cards: [DashboardCard]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small * 2) {
            Text("Your city").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.medium), GridItem(.flexible())], spacing: Spacing.medium) {
                ForEach(cards) { card in
                    NavigationLink(value: card.section) {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Image(systemName: card.section.systemImage)
                                .foregroundStyle(Palette.accent)
                            Text(card.summary.title)
                                .font(.subheadline.weight(.semibold))
                            Text(card.summary.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2, reservesSpace: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.medium)
                        .background(Palette.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.medium)
    }
}

#Preview {
    NavigationStack {
        HomeScreen(service: PreviewHomeService(), events: EventsEntryPoints { AnyView(Text($0)) }) { AnyView(Text($0.title)) }
    }
}
