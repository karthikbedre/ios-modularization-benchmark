import CoreKit
import CoreModels
@testable import Dining
import DiningAPI
import Testing

private func restaurant(_ id: String, _ cuisine: Cuisine, price: Int, rating: Double, reservable: Bool = true) -> Restaurant {
    Restaurant(id: id, name: id.capitalized, cuisine: cuisine, priceLevel: price, rating: rating, reviewCount: 10, placeID: "p",
               district: "Old Town", openingHours: "", acceptsReservations: reservable, highlights: [])
}

private func item(_ name: String, _ tags: Set<DietaryTag>) -> MenuItem {
    MenuItem(id: name, name: name, details: "", price: .usd(10), dietary: tags)
}

private let catalog = DiningCatalog(
    restaurants: [
        restaurant("ramen", .noodles, price: 2, rating: 4.6),
        restaurant("grill", .seafood, price: 4, rating: 4.4),
        restaurant("garden", .vegetarian, price: 2, rating: 4.7),
        restaurant("bakery", .bakery, price: 1, rating: 4.6, reservable: false),
    ],
    menus: [
        "ramen": [MenuSection(title: "Bowls", items: [item("Tonkotsu", []), item("Veg Ramen", [.vegetarian, .vegan])])],
        "grill": [MenuSection(title: "Mains", items: [item("Halibut", [.glutenFree])])],
        "garden": [MenuSection(title: "Bowls", items: [item("Harvest", [.vegetarian, .vegan, .glutenFree])]),
                   MenuSection(title: "Sweets", items: [item("Cake", [.vegetarian])])],
        "bakery": [],
    ]
)

struct RestaurantQueryTests {
    @Test func defaultSortsByRatingThenName() {
        let result = RestaurantQuery.apply(DiningFilter(), to: catalog.restaurants, menus: catalog.menus)

        #expect(result.map(\.id) == ["garden", "bakery", "ramen", "grill"])
    }

    @Test func filtersCombine() {
        let filter = DiningFilter(maxPriceLevel: 2, reservableOnly: true, sort: .name)

        #expect(RestaurantQuery.apply(filter, to: catalog.restaurants, menus: catalog.menus).map(\.id) == ["garden", "ramen"])
    }

    @Test func dietaryNeedsOneItemMatchingEveryTag() {
        let vegan = DiningFilter(dietary: [.vegan])
        let veganGlutenFree = DiningFilter(dietary: [.vegan, .glutenFree])

        #expect(RestaurantQuery.apply(vegan, to: catalog.restaurants, menus: catalog.menus).map(\.id) == ["garden", "ramen"])
        #expect(RestaurantQuery.apply(veganGlutenFree, to: catalog.restaurants, menus: catalog.menus).map(\.id) == ["garden"])
    }

    @Test func priceSortBreaksTiesByRating() {
        let result = RestaurantQuery.apply(DiningFilter(sort: .price), to: catalog.restaurants, menus: catalog.menus)

        #expect(result.map(\.id) == ["bakery", "garden", "ramen", "grill"])
    }

    @Test func menuFilterDropsEmptySections() {
        let menu = RestaurantQuery.menu(catalog.menus["garden"]!, matching: [.vegan])

        #expect(menu.map(\.title) == ["Bowls"])
        #expect(RestaurantQuery.menu(catalog.menus["garden"]!, matching: []).count == 2)
    }

    @Test func defaultFilterIgnoresSort() {
        #expect(DiningFilter(sort: .name).isDefault)
        #expect(!DiningFilter(cuisine: .bakery).isDefault)
    }
}

struct LiveDiningServiceTests {
    private let service = LiveDiningService(repository: InMemoryDiningRepository(stored: catalog))

    @Test func searchMatchesNamesCuisinesAndDishes() async throws {
        #expect(try await service.search("halibut").map(\.id) == ["grill"])
        #expect(try await service.search("noodles").map(\.id) == ["ramen"])
        #expect(try await service.search(" ").isEmpty)
    }

    @Test func unknownRestaurantThrowsForDetailAndMenu() async {
        await #expect(throws: DiningError.notFound) { try await service.restaurant(id: "missing") }
        await #expect(throws: DiningError.notFound) { try await service.menu(restaurantID: "missing") }
    }

    @Test func bundledCatalogHasAMenuForEveryRestaurant() async throws {
        let bundled = try await BundleDiningRepository(loader: MockDataLoader(latency: .none)).catalog()

        #expect(bundled.restaurants.count == 7)
        #expect(bundled.restaurants.allSatisfy { bundled.menus[$0.id]?.isEmpty == false })
    }
}

@MainActor
struct DiningViewModelTests {
    @Test func searchOverridesFilterAndResetKeepsSort() async {
        let viewModel = DiningViewModel(service: LiveDiningService(repository: InMemoryDiningRepository(stored: catalog)))
        viewModel.filter = DiningFilter(cuisine: .seafood, sort: .name)
        await viewModel.load()
        #expect(viewModel.state.value?.map(\.id) == ["grill"])

        viewModel.searchText = "veg"
        await viewModel.load()
        #expect(viewModel.state.value?.map(\.id) == ["garden", "ramen"])

        viewModel.resetFilter()
        #expect(viewModel.filter == DiningFilter(sort: .name))
    }

    @Test func restaurantMapsToCrossDomainDrafts() {
        let ramen = catalog.restaurants[0]

        #expect(ramen.favoriteDraft.subtitle == "Noodles · Old Town")
        #expect(ramen.bookableVenue.kind == .dining)
    }
}
