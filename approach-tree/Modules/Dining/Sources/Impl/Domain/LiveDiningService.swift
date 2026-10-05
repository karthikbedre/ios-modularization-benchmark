import CoreModels
import Foundation

public struct LiveDiningService: DiningService {
    private let repository: any DiningRepository

    init(repository: any DiningRepository) {
        self.repository = repository
    }

    public func restaurants(matching filter: DiningFilter) async throws -> [Restaurant] {
        let catalog = try await repository.catalog()
        return RestaurantQuery.apply(filter, to: catalog.restaurants, menus: catalog.menus)
    }

    public func restaurant(id: String) async throws -> Restaurant {
        guard let restaurant = try await repository.catalog().restaurants.first(where: { $0.id == id }) else {
            throw DiningError.notFound
        }
        return restaurant
    }

    public func menu(restaurantID: String) async throws -> [MenuSection] {
        let catalog = try await repository.catalog()
        guard catalog.restaurants.contains(where: { $0.id == restaurantID }) else { throw DiningError.notFound }
        return catalog.menus[restaurantID] ?? []
    }

    public func search(_ text: String) async throws -> [Restaurant] {
        let needle = text.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }
        let catalog = try await repository.catalog()
        return catalog.restaurants.filter { restaurant in
            restaurant.name.localizedStandardContains(needle)
                || restaurant.cuisine.title.localizedStandardContains(needle)
                || restaurant.district.localizedStandardContains(needle)
                || (catalog.menus[restaurant.id] ?? []).contains { $0.items.contains { $0.name.localizedStandardContains(needle) } }
        }
        .sorted { $0.rating > $1.rating }
    }

    public func summary() async -> DomainSummary {
        guard let top = try? await restaurants(matching: DiningFilter()).first else {
            return DomainSummary(title: "Dining", detail: "Unavailable")
        }
        return DomainSummary(title: "Dining", detail: "Top rated: \(top.name) \(top.rating.formatted(.number.precision(.fractionLength(1))))★")
    }
}

enum RestaurantQuery {
    static func apply(_ filter: DiningFilter, to restaurants: [Restaurant], menus: [String: [MenuSection]]) -> [Restaurant] {
        restaurants
            .filter { restaurant in
                (filter.cuisine == nil || restaurant.cuisine == filter.cuisine)
                    && restaurant.priceLevel <= filter.maxPriceLevel
                    && (!filter.reservableOnly || restaurant.acceptsReservations)
                    && (filter.dietary.isEmpty || serves(filter.dietary, menu: menus[restaurant.id] ?? []))
            }
            .sorted { lhs, rhs in
                switch filter.sort {
                case .rating: lhs.rating != rhs.rating ? lhs.rating > rhs.rating : lhs.name < rhs.name
                case .name: lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                case .price: lhs.priceLevel != rhs.priceLevel ? lhs.priceLevel < rhs.priceLevel : lhs.rating > rhs.rating
                }
            }
    }

    static func serves(_ tags: Set<DietaryTag>, menu: [MenuSection]) -> Bool {
        menu.contains { $0.items.contains { tags.isSubset(of: $0.dietary) } }
    }

    /// The menu with only items matching every tag, dropping empty sections.
    static func menu(_ menu: [MenuSection], matching tags: Set<DietaryTag>) -> [MenuSection] {
        guard !tags.isEmpty else { return menu }
        return menu.compactMap { section in
            let items = section.items.filter { tags.isSubset(of: $0.dietary) }
            return items.isEmpty ? nil : MenuSection(title: section.title, items: items)
        }
    }
}
