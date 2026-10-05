import Foundation

public enum SearchScope: String, CaseIterable, Hashable, Sendable {
    case events, restaurants, books, stops, places

    public var title: String {
        switch self {
        case .events: "Events"
        case .restaurants: "Restaurants"
        case .books: "Books"
        case .stops: "Transit stops"
        case .places: "Places"
        }
    }
}

public struct SearchResult: Identifiable, Hashable, Sendable {
    public var scope: SearchScope
    /// The ID the owning domain uses for this item.
    public var itemID: String
    public var title: String
    public var subtitle: String

    public init(scope: SearchScope, itemID: String, title: String, subtitle: String) {
        self.scope = scope
        self.itemID = itemID
        self.title = title
        self.subtitle = subtitle
    }

    public var id: String { "\(scope.rawValue)-\(itemID)" }
}

public struct SearchResponse: Hashable, Sendable {
    public var results: [SearchResult]
    /// Scopes whose source failed. Results from the other scopes are still returned.
    public var unavailable: Set<SearchScope>

    public init(results: [SearchResult], unavailable: Set<SearchScope>) {
        self.results = results
        self.unavailable = unavailable
    }
}
