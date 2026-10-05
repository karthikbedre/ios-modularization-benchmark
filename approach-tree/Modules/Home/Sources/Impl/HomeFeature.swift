import Agenda
import DI
import Dining
import Events
import Favorites
import Identity
import Library
import Notifications
import Parking
import ReportIssue
import Reservations
import Search
import SwiftUI
import Tickets
import Transit
import Wallet

public enum HomeFeature {
    public static func register(in container: Container) {
        container.registerShared((any HomeService).self) {
            LiveHomeService(sources: HomeSources(
                identity: container.resolve((any IdentityService).self),
                notifications: container.resolve((any NotificationsService).self),
                agenda: container.resolve((any AgendaService).self),
                favorites: container.resolve((any FavoritesService).self),
                wallet: container.resolve((any WalletService).self),
                tickets: container.resolve((any TicketsService).self),
                reservations: container.resolve((any ReservationsService).self),
                events: container.resolve((any EventsService).self),
                dining: container.resolve((any DiningService).self),
                parking: container.resolve((any ParkingService).self),
                transit: container.resolve((any TransitService).self),
                library: container.resolve((any LibraryService).self),
                reports: container.resolve((any ReportIssueService).self),
                search: container.resolve((any SearchService).self)
            ))
        }
    }

    @MainActor
    public static func makeScreen(container: Container, route: @escaping HomeRouter) -> some View {
        HomeScreen(service: container.resolve((any HomeService).self), events: container.resolve(EventsEntryPoints.self), route: route)
    }
}
