import AgendaAPI
import CoreKit
import CoreModels
import DiningAPI
import EventsAPI
import FavoritesAPI
import Foundation
import HomeAPI
import IdentityAPI
import LibraryAPI
import NotificationsAPI
import ParkingAPI
import ReportIssueAPI
import ReservationsAPI
import SearchAPI
import TicketsAPI
import TransitAPI
import WalletAPI

/// The services the dashboard reads from, one per section.
struct HomeSources: Sendable {
    var identity: any IdentityService
    var notifications: any NotificationsService
    var agenda: any AgendaService
    var favorites: any FavoritesService
    var wallet: any WalletService
    var tickets: any TicketsService
    var reservations: any ReservationsService
    var events: any EventsService
    var dining: any DiningService
    var parking: any ParkingService
    var transit: any TransitService
    var library: any LibraryService
    var reports: any ReportIssueService
    var search: any SearchService

    func provider(for section: HomeSection) -> any SummaryProviding {
        switch section {
        case .profile: identity
        case .inbox: notifications
        case .agenda: agenda
        case .saved: favorites
        case .wallet: wallet
        case .tickets: tickets
        case .reservations: reservations
        case .events: events
        case .dining: dining
        case .parking: parking
        case .transit: transit
        case .library: library
        case .reports: reports
        case .search: search
        }
    }
}

public struct LiveHomeService: HomeService {
    private let sources: HomeSources
    private let dates: DateProvider
    private let calendar: Calendar

    init(sources: HomeSources, dates: DateProvider = .live, calendar: Calendar = .current) {
        self.sources = sources
        self.dates = dates
        self.calendar = calendar
    }

    public func dashboard() async -> Dashboard {
        async let greeting = greeting()
        async let unread = (try? sources.notifications.unreadCount()) ?? 0
        async let upNext = (try? sources.agenda.upcoming(limit: 3)) ?? []
        async let featured = (try? sources.events.featured()) ?? []
        async let cards = cards()

        return await Dashboard(
            greeting: greeting,
            unreadCount: unread,
            upNext: upNext.map { UpNextItem(id: $0.id, title: $0.title, start: $0.start, location: $0.location) },
            featuredEvents: featured.prefix(4).map { FeaturedEvent(id: $0.id, title: $0.title, start: $0.start, venueName: $0.venueName) },
            cards: cards
        )
    }

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Home", detail: await greeting())
    }

    /// Summaries load concurrently, since each one may wait on its own simulated backend.
    private func cards() async -> [DashboardCard] {
        let sources = sources
        let summaries = await withTaskGroup(of: (HomeSection, DomainSummary).self) { group in
            for section in HomeSection.allCases where section != .search {
                group.addTask { (section, await sources.provider(for: section).summary()) }
            }
            var summaries: [HomeSection: DomainSummary] = [:]
            for await (section, summary) in group {
                summaries[section] = summary
            }
            return summaries
        }
        return HomeSection.allCases.compactMap { section in summaries[section].map { DashboardCard(section: section, summary: $0) } }
    }

    private func greeting() async -> String {
        let hour = calendar.component(.hour, from: dates.now)
        let part = switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
        guard let name = try? await sources.identity.currentUser().firstName else { return part }
        return "\(part), \(name)"
    }
}
