import Foundation

public enum FavoriteKind: String, CaseIterable, Hashable, Sendable, Codable {
    case event, restaurant, transitStop, book

    public var title: String {
        switch self {
        case .event: "Events"
        case .restaurant: "Restaurants"
        case .transitStop: "Stops"
        case .book: "Books"
        }
    }
}

/// What a domain hands over when a resident saves something. Favorites stores a copy of the
/// title and subtitle so the saved list renders without calling back into every domain.
public struct FavoriteDraft: Hashable, Sendable {
    public var kind: FavoriteKind
    public var itemID: String
    public var title: String
    public var subtitle: String

    public init(kind: FavoriteKind, itemID: String, title: String, subtitle: String) {
        self.kind = kind
        self.itemID = itemID
        self.title = title
        self.subtitle = subtitle
    }
}

public struct FavoriteItem: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var ownerID: String
    public var kind: FavoriteKind
    public var itemID: String
    public var title: String
    public var subtitle: String
    public var addedAt: Date

    public init(id: String, ownerID: String, kind: FavoriteKind, itemID: String, title: String, subtitle: String, addedAt: Date) {
        self.id = id
        self.ownerID = ownerID
        self.kind = kind
        self.itemID = itemID
        self.title = title
        self.subtitle = subtitle
        self.addedAt = addedAt
    }
}

public enum FavoritesError: Error, Hashable, Sendable {
    case limitReached(Int)
    case notFound
}
