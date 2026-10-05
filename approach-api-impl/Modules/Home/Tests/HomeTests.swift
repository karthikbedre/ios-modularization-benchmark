import AgendaAPI
import CoreKit
import DiningAPI
import EventsAPI
import FavoritesAPI
import Foundation
@testable import Home
import HomeAPI
import IdentityAPI
import LibraryAPI
import NotificationsAPI
import ParkingAPI
import ReportIssueAPI
import ReservationsAPI
import SearchAPI
import Testing
import TicketsAPI
import TransitAPI
import WalletAPI

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func at(hour: Int) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: hour))!
}

private let previewSources = HomeSources(
    identity: PreviewIdentityService(),
    notifications: PreviewNotificationsService(),
    agenda: PreviewAgendaService(),
    favorites: PreviewFavoritesService(),
    wallet: PreviewWalletService(),
    tickets: PreviewTicketsService(),
    reservations: PreviewReservationsService(),
    events: PreviewEventsService(),
    dining: PreviewDiningService(),
    parking: PreviewParkingService(),
    transit: PreviewTransitService(),
    library: PreviewLibraryService(),
    reports: PreviewReportIssueService(),
    search: PreviewSearchService()
)

struct LiveHomeServiceTests {
    @Test func dashboardHasACardPerServiceInSectionOrder() async {
        let dashboard = await LiveHomeService(sources: previewSources, dates: .fixed(at(hour: 9)), calendar: utc).dashboard()

        #expect(dashboard.cards.map(\.section) == HomeSection.allCases.filter { $0 != .search })
        #expect(dashboard.cards.first { $0.section == .wallet }?.summary.title == "Wallet")
        #expect(dashboard.unreadCount == 1)
        #expect(dashboard.upNext.map(\.title) == ["Autumn Jazz Night"])
        #expect(dashboard.featuredEvents.map(\.id) == ["event-jazz"])
    }

    @Test(arguments: [(6, "Good morning, Avery"), (13, "Good afternoon, Avery"), (20, "Good evening, Avery"), (2, "Good evening, Avery")])
    func greetingFollowsTimeOfDay(hour: Int, expected: String) async {
        let service = LiveHomeService(sources: previewSources, dates: .fixed(at(hour: hour)), calendar: utc)

        #expect(await service.dashboard().greeting == expected)
        #expect(await service.summary().detail == expected)
    }

    @Test func everySectionHasAProvider() async {
        for section in HomeSection.allCases {
            #expect(!(await previewSources.provider(for: section).summary().title.isEmpty))
        }
    }
}

@MainActor
struct HomeViewModelTests {
    @Test func loadsTheDashboard() async {
        let viewModel = HomeViewModel(service: PreviewHomeService())

        await viewModel.load()

        #expect(viewModel.state.value?.greeting == "Good evening, Avery")
    }
}
