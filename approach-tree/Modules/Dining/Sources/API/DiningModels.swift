import CoreModels
import Foundation

public enum Cuisine: String, CaseIterable, Hashable, Sendable, Codable {
    case noodles, seafood, vegetarian, mexican, italian, bakery, korean

    public var title: String { rawValue.capitalized }
}

public enum DietaryTag: String, CaseIterable, Hashable, Sendable, Codable {
    case vegetarian, vegan, glutenFree, nutFree

    public var title: String {
        switch self {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten free"
        case .nutFree: "Nut free"
        }
    }
}

public struct Restaurant: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var cuisine: Cuisine
    /// 1 to 4, shown as dollar signs.
    public var priceLevel: Int
    public var rating: Double
    public var reviewCount: Int
    public var placeID: String
    public var district: String
    public var openingHours: String
    public var acceptsReservations: Bool
    public var highlights: [String]

    public init(id: String, name: String, cuisine: Cuisine, priceLevel: Int, rating: Double, reviewCount: Int, placeID: String, district: String, openingHours: String, acceptsReservations: Bool, highlights: [String]) {
        self.id = id
        self.name = name
        self.cuisine = cuisine
        self.priceLevel = priceLevel
        self.rating = rating
        self.reviewCount = reviewCount
        self.placeID = placeID
        self.district = district
        self.openingHours = openingHours
        self.acceptsReservations = acceptsReservations
        self.highlights = highlights
    }

    public var priceSymbol: String { String(repeating: "$", count: priceLevel) }
}

public struct MenuItem: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var details: String
    public var price: Money
    public var dietary: Set<DietaryTag>

    public init(id: String, name: String, details: String, price: Money, dietary: Set<DietaryTag>) {
        self.id = id
        self.name = name
        self.details = details
        self.price = price
        self.dietary = dietary
    }
}

public struct MenuSection: Identifiable, Hashable, Sendable, Codable {
    public var title: String
    public var items: [MenuItem]

    public init(title: String, items: [MenuItem]) {
        self.title = title
        self.items = items
    }

    public var id: String { title }
}

public struct DiningFilter: Hashable, Sendable {
    public enum Sort: String, CaseIterable, Hashable, Sendable {
        case rating, name, price
    }

    public var cuisine: Cuisine?
    public var maxPriceLevel: Int
    public var reservableOnly: Bool
    /// Restaurants with at least one menu item matching every tag.
    public var dietary: Set<DietaryTag>
    public var sort: Sort

    public init(cuisine: Cuisine? = nil, maxPriceLevel: Int = 4, reservableOnly: Bool = false, dietary: Set<DietaryTag> = [], sort: Sort = .rating) {
        self.cuisine = cuisine
        self.maxPriceLevel = maxPriceLevel
        self.reservableOnly = reservableOnly
        self.dietary = dietary
        self.sort = sort
    }

    public var isDefault: Bool { self == DiningFilter(sort: sort) }
}

public enum DiningError: Error, Hashable, Sendable {
    case notFound
}
