import CoreModels
import Foundation

/// Every place the dashboard can send the resident. The app's composition root maps each to a screen.
public enum HomeSection: String, CaseIterable, Hashable, Sendable {
    case profile, inbox, agenda, saved, wallet, tickets, reservations, events, dining, parking, transit, library, reports, search

    public var title: String {
        switch self {
        case .profile: "Profile"
        case .inbox: "Inbox"
        case .agenda: "Agenda"
        case .saved: "Saved"
        case .wallet: "Wallet"
        case .tickets: "Tickets"
        case .reservations: "Reservations"
        case .events: "Events"
        case .dining: "Dining"
        case .parking: "Parking"
        case .transit: "Transit"
        case .library: "Library"
        case .reports: "Report an issue"
        case .search: "Search"
        }
    }

    public var systemImage: String {
        switch self {
        case .profile: "person.crop.circle"
        case .inbox: "tray"
        case .agenda: "calendar"
        case .saved: "heart"
        case .wallet: "creditcard"
        case .tickets: "ticket"
        case .reservations: "calendar.badge.clock"
        case .events: "music.mic"
        case .dining: "fork.knife"
        case .parking: "parkingsign.circle"
        case .transit: "tram"
        case .library: "books.vertical"
        case .reports: "wrench.and.screwdriver"
        case .search: "magnifyingglass"
        }
    }
}

public struct DashboardCard: Identifiable, Hashable, Sendable {
    public var section: HomeSection
    public var summary: DomainSummary

    public init(section: HomeSection, summary: DomainSummary) {
        self.section = section
        self.summary = summary
    }

    public var id: HomeSection { section }
}

public struct UpNextItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var location: String?

    public init(id: String, title: String, start: Date, location: String?) {
        self.id = id
        self.title = title
        self.start = start
        self.location = location
    }
}

public struct FeaturedEvent: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var venueName: String

    public init(id: String, title: String, start: Date, venueName: String) {
        self.id = id
        self.title = title
        self.start = start
        self.venueName = venueName
    }
}

public struct Dashboard: Hashable, Sendable {
    public var greeting: String
    public var unreadCount: Int
    public var upNext: [UpNextItem]
    public var featuredEvents: [FeaturedEvent]
    /// One card per service, in `HomeSection.allCases` order.
    public var cards: [DashboardCard]

    public init(greeting: String, unreadCount: Int, upNext: [UpNextItem], featuredEvents: [FeaturedEvent], cards: [DashboardCard]) {
        self.greeting = greeting
        self.unreadCount = unreadCount
        self.upNext = upNext
        self.featuredEvents = featuredEvents
        self.cards = cards
    }
}
