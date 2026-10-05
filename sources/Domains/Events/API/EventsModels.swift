import CoreModels
import Foundation

public enum EventCategory: String, CaseIterable, Hashable, Sendable, Codable {
    case music, film, food, family, sports, community, arts

    public var title: String {
        switch self {
        case .music: "Music"
        case .film: "Film"
        case .food: "Food"
        case .family: "Family"
        case .sports: "Sports"
        case .community: "Community"
        case .arts: "Arts"
        }
    }
}

public struct CityEvent: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var title: String
    public var summary: String
    public var category: EventCategory
    public var start: Date
    public var end: Date
    public var venuePlaceID: String
    public var venueName: String
    public var organizer: String
    /// Nil for free events. Otherwise the cheapest ticket.
    public var priceFrom: Money?
    public var isFeatured: Bool
    public var tags: [String]

    public init(id: String, title: String, summary: String, category: EventCategory, start: Date, end: Date, venuePlaceID: String, venueName: String, organizer: String, priceFrom: Money?, isFeatured: Bool, tags: [String]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.category = category
        self.start = start
        self.end = end
        self.venuePlaceID = venuePlaceID
        self.venueName = venueName
        self.organizer = organizer
        self.priceFrom = priceFrom
        self.isFeatured = isFeatured
        self.tags = tags
    }

    public var isFree: Bool { priceFrom == nil }
}

public enum EventsError: Error, Hashable, Sendable {
    case notFound
}
