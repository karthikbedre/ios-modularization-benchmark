import CoreKit
import CoreModels
import Dining
import Events
import Identity
import Library
import Map
import Notifications
import Parking
import ReportIssue
import Reservations
import Tickets
import Transit
import Wallet

public struct LiveHomeService: HomeService {
    private let identity: any IdentityService
    private let map: any MapService
    private let notifications: any NotificationsService
    private let wallet: any WalletService
    private let tickets: any TicketsService
    private let events: any EventsService
    private let parking: any ParkingService
    private let transit: any TransitService
    private let reservations: any ReservationsService
    private let dining: any DiningService
    private let library: any LibraryService
    private let reportIssue: any ReportIssueService
    private let latency: Latency

    public init(identity: any IdentityService, map: any MapService, notifications: any NotificationsService, wallet: any WalletService, tickets: any TicketsService, events: any EventsService, parking: any ParkingService, transit: any TransitService, reservations: any ReservationsService, dining: any DiningService, library: any LibraryService, reportIssue: any ReportIssueService, latency: Latency = .standard) {
        self.identity = identity
        self.map = map
        self.notifications = notifications
        self.wallet = wallet
        self.tickets = tickets
        self.events = events
        self.parking = parking
        self.transit = transit
        self.reservations = reservations
        self.dining = dining
        self.library = library
        self.reportIssue = reportIssue
        self.latency = latency
    }

    var dependencies: [any SummaryProviding] {
        [identity, map, notifications, wallet, tickets, events, parking, transit, reservations, dining, library, reportIssue]
    }

    public func summary() async -> DomainSummary {
        await latency.wait()
        let detail = dependencies.isEmpty ? "No dependencies" : "Uses \(dependencies.count) services"
        return DomainSummary(title: "Home", detail: detail)
    }

    func allSummaries() async -> [DomainSummary] {
        var summaries = [await summary()]
        for dependency in dependencies {
            summaries.append(await dependency.summary())
        }
        return summaries
    }
}
