import DesignSystem
import DiningAPI
import SwiftUI

struct DiningScreen: View {
    @State private var viewModel: DiningViewModel
    @State private var editsFilter = false
    private let ui: DiningUI

    init(service: any DiningService, ui: DiningUI) {
        _viewModel = State(initialValue: DiningViewModel(service: service))
        self.ui = ui
    }

    var body: some View {
        AsyncContentView(state: viewModel.state, retry: viewModel.load) { restaurants in
            if restaurants.isEmpty {
                ContentUnavailableView {
                    Label("No restaurants", systemImage: "fork.knife")
                } description: {
                    Text("Nothing matches these filters.")
                } actions: {
                    Button("Clear filters") { viewModel.resetFilter() }
                }
            } else {
                List(restaurants) { restaurant in
                    NavigationLink(value: restaurant) { RestaurantRow(restaurant: restaurant) }
                }
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Dining")
        .searchable(text: $viewModel.searchText, prompt: "Restaurants, dishes, neighborhoods")
        .toolbar {
            Button("Filters", systemImage: viewModel.filter.isDefault ? "slider.horizontal.3" : "slider.horizontal.below.square.filled.and.square") {
                editsFilter = true
            }
        }
        .sheet(isPresented: $editsFilter) {
            NavigationStack {
                DiningFilterScreen(filter: $viewModel.filter)
            }
            .presentationDetents([.medium, .large])
        }
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailScreen(restaurant: restaurant, service: viewModel.service, ui: ui)
        }
        .task(id: viewModel.filter) { await viewModel.load() }
        .task(id: viewModel.searchText) { await viewModel.load() }
    }
}

struct RestaurantRow: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                Text(restaurant.name).font(.headline)
                Spacer()
                Text(restaurant.priceSymbol)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Spacing.small * 2) {
                RatingView(rating: restaurant.rating, reviewCount: restaurant.reviewCount)
                Text("\(restaurant.cuisine.title) · \(restaurant.district)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if restaurant.acceptsReservations {
                    StatusBadge("Reservable")
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct DiningFilterScreen: View {
    @Binding var filter: DiningFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Sort by") {
                Picker("Sort", selection: $filter.sort) {
                    Text("Rating").tag(DiningFilter.Sort.rating)
                    Text("Name").tag(DiningFilter.Sort.name)
                    Text("Price").tag(DiningFilter.Sort.price)
                }
                .pickerStyle(.segmented)
            }
            Section("Cuisine") {
                Picker("Cuisine", selection: $filter.cuisine) {
                    Text("Any").tag(Cuisine?.none)
                    ForEach(Cuisine.allCases, id: \.self) { cuisine in
                        Text(cuisine.title).tag(Optional(cuisine))
                    }
                }
            }
            Section("Price") {
                Picker("Up to", selection: $filter.maxPriceLevel) {
                    ForEach(1...4, id: \.self) { level in
                        Text(String(repeating: "$", count: level)).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Takes reservations", isOn: $filter.reservableOnly)
            }
            Section("Dietary") {
                ForEach(DietaryTag.allCases, id: \.self) { tag in
                    Toggle(tag.title, isOn: Binding {
                        filter.dietary.contains(tag)
                    } set: { isOn in
                        if isOn { filter.dietary.insert(tag) } else { filter.dietary.remove(tag) }
                    })
                }
            }
        }
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Reset") { filter = DiningFilter(sort: filter.sort) }
                    .disabled(filter.isDefault)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DiningScreen(service: PreviewDiningService(), ui: .preview)
    }
}
