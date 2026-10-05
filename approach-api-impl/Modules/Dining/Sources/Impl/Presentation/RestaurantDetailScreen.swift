import CoreKit
import DesignSystem
import DiningAPI
import SwiftUI

struct RestaurantDetailScreen: View {
    let restaurant: Restaurant
    let service: any DiningService
    let ui: DiningUI
    @State private var menu: LoadState<[MenuSection]> = .idle
    @State private var dietary: Set<DietaryTag> = []
    @State private var books = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text(restaurant.name).font(.title2.weight(.bold))
                    HStack(spacing: Spacing.small * 2) {
                        RatingView(rating: restaurant.rating, reviewCount: restaurant.reviewCount)
                        Text("\(restaurant.cuisine.title) · \(restaurant.priceSymbol)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(restaurant.highlights, id: \.self) { highlight in
                        Label(highlight, systemImage: "sparkles")
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, Spacing.small)
            }
            Section {
                KeyValueRow("Hours", value: restaurant.openingHours)
                NavigationLink {
                    ui.places.place(restaurant.placeID)
                } label: {
                    KeyValueRow("Neighborhood", value: restaurant.district)
                }
                if restaurant.acceptsReservations {
                    Button("Book a table", systemImage: "calendar.badge.plus") { books = true }
                } else {
                    Label("Walk-ins only", systemImage: "figure.walk")
                        .foregroundStyle(.secondary)
                }
            }
            menuSections
        }
        .navigationTitle(restaurant.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ui.favorites.toggleButton(restaurant.favoriteDraft)
        }
        .sheet(isPresented: $books) {
            NavigationStack {
                ui.reservations.booking(restaurant.bookableVenue)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { books = false }
                        }
                    }
            }
        }
        .task { await loadMenu() }
    }

    @ViewBuilder
    private var menuSections: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(DietaryTag.allCases, id: \.self) { tag in
                        Toggle(tag.title, isOn: Binding {
                            dietary.contains(tag)
                        } set: { isOn in
                            if isOn { dietary.insert(tag) } else { dietary.remove(tag) }
                        })
                        .toggleStyle(.button)
                        .font(.caption)
                    }
                }
            }
        } header: {
            Text("Menu")
        }
        switch menu {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .failed(let message):
            Text(message).foregroundStyle(.secondary)
        case .loaded(let sections):
            let visible = RestaurantQuery.menu(sections, matching: dietary)
            if visible.isEmpty {
                Text("No dishes match those dietary needs.").foregroundStyle(.secondary)
            }
            ForEach(visible) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        MenuItemRow(item: item)
                    }
                }
            }
        }
    }

    private func loadMenu() async {
        do {
            menu = .loaded(try await service.menu(restaurantID: restaurant.id))
        } catch {
            menu = .failed("The menu is not available.")
        }
    }
}

private struct MenuItemRow: View {
    let item: MenuItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(item.name)
                Spacer()
                AmountText(item.price)
            }
            Text(item.details)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !item.dietary.isEmpty {
                Text(DietaryTag.allCases.filter(item.dietary.contains).map(\.title).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(Palette.positive)
            }
        }
    }
}

struct RestaurantLookupScreen: View {
    let restaurantID: String
    let service: any DiningService
    let ui: DiningUI
    @State private var restaurant: LoadState<Restaurant> = .idle

    var body: some View {
        AsyncContentView(state: restaurant, retry: load) { restaurant in
            RestaurantDetailScreen(restaurant: restaurant, service: service, ui: ui)
        }
        .task {
            if case .idle = restaurant { await load() }
        }
    }

    private func load() async {
        do {
            restaurant = .loaded(try await service.restaurant(id: restaurantID))
        } catch {
            restaurant = .failed("This restaurant could not be found.")
        }
    }
}

#Preview {
    NavigationStack {
        RestaurantDetailScreen(restaurant: .preview, service: PreviewDiningService(), ui: .preview)
    }
}
