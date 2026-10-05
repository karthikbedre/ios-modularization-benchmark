#if DEBUG
import CoreModels
import Foundation

extension Restaurant {
    public static let preview = Restaurant(
        id: "rest-noodle-88", name: "Noodle Bar 88", cuisine: .noodles, priceLevel: 2, rating: 4.6, reviewCount: 812,
        placeID: "place-noodle-88", district: "Old Town", openingHours: "11 AM to 10 PM", acceptsReservations: true,
        highlights: ["Hand-pulled noodles", "Late kitchen on Fridays"]
    )
}

public struct PreviewDiningService: DiningService {
    public init() {}

    public func restaurants(matching filter: DiningFilter) async throws -> [Restaurant] { [.preview] }
    public func restaurant(id: String) async throws -> Restaurant { .preview }

    public func menu(restaurantID: String) async throws -> [MenuSection] {
        [MenuSection(title: "Noodles", items: [
            MenuItem(id: "m1", name: "Beef Lamian", details: "Hand-pulled noodles, 8 hour broth", price: .usd(16), dietary: []),
            MenuItem(id: "m2", name: "Garden Dan Dan", details: "Sesame, chili, greens", price: .usd(14), dietary: [.vegetarian, .vegan]),
        ])]
    }

    public func search(_ text: String) async throws -> [Restaurant] { [.preview] }

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Dining", detail: "Top rated: Noodle Bar 88")
    }
}
#endif
