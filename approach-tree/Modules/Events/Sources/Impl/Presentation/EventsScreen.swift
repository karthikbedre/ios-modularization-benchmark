import DesignSystem
import SwiftUI

struct EventsScreen: View {
    @State private var viewModel: EventsViewModel
    private let ui: EventsUI

    init(service: any EventsService, ui: EventsUI) {
        _viewModel = State(initialValue: EventsViewModel(service: service))
        self.ui = ui
    }

    var body: some View {
        AsyncContentView(state: viewModel.state, retry: viewModel.load) { content in
            List {
                if viewModel.isSearching {
                    searchResults
                } else {
                    if !content.featured.isEmpty {
                        Section {
                            FeaturedCarousel(events: content.featured)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }
                    Section {
                        CategoryPicker(selection: $viewModel.category)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    if content.sections.isEmpty {
                        EmptyStateView("No events", systemImage: "calendar", message: "Nothing in this category right now.")
                    }
                    ForEach(content.sections) { section in
                        Section(section.period.title) {
                            ForEach(section.events) { event in
                                NavigationLink(value: event) { EventRow(event: event) }
                            }
                        }
                    }
                }
            }
            .refreshable { await viewModel.load() }
        }
        .navigationTitle("Events")
        .searchable(text: $viewModel.searchText, prompt: "Events, venues, tags")
        .navigationDestination(for: CityEvent.self) { event in
            EventDetailScreen(event: event, ui: ui)
        }
        .task(id: viewModel.category) { await viewModel.load() }
        .task(id: viewModel.searchText) { await viewModel.runSearch() }
    }

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.searchResults.isEmpty {
            EmptyStateView("No matches", systemImage: "magnifyingglass", message: "Try a venue, a category or a word like \"outdoor\".")
        } else {
            ForEach(viewModel.searchResults) { event in
                NavigationLink(value: event) { EventRow(event: event) }
            }
        }
    }
}

private struct FeaturedCarousel: View {
    let events: [CityEvent]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.medium) {
                ForEach(events) { event in
                    NavigationLink(value: event) {
                        FeaturedCard(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.medium)
        }
    }
}

private struct FeaturedCard: View {
    let event: CityEvent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Image(systemName: event.category.systemImage)
                .font(.title)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Text(event.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(event.start.formatted(.dateTime.weekday(.wide).hour().minute()))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(Spacing.medium)
        .frame(width: 220, height: 140, alignment: .leading)
        .background(
            LinearGradient(colors: [event.category.tint, event.category.tint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Radius.card)
        )
    }
}

private struct CategoryPicker: View {
    @Binding var selection: EventCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.small * 2) {
                chip("All", isSelected: selection == nil) { selection = nil }
                ForEach(EventCategory.allCases, id: \.self) { category in
                    chip(category.title, isSelected: selection == category) {
                        selection = selection == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, Spacing.medium)
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small * 2)
            .background(isSelected ? Palette.accent : Palette.cardBackground, in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
            .buttonStyle(.plain)
    }
}

struct EventRow: View {
    let event: CityEvent

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: event.category.systemImage)
                .foregroundStyle(event.category.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                Text("\(event.start.formatted(.dateTime.weekday().hour().minute())) · \(event.venueName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let price = event.priceFrom {
                Text("from \(price.formatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                StatusBadge("Free", color: Palette.positive)
            }
        }
    }
}

#Preview {
    NavigationStack {
        EventsScreen(service: PreviewEventsService(), ui: .preview)
    }
}
