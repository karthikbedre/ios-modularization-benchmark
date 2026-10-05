import Agenda
import DI
import Dining
import Events
import Favorites
import Home
import Identity
import Library
import Notifications
import Parking
import Places
import ReportIssue
import Reservations
import Search
import SwiftUI
import Tickets
import Transit
import Wallet

@main
struct CivitasApp: App {
    private let container = CivitasApp.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container, router: AppRouter(container: container))
        }
    }

    /// Registration order does not matter. Services resolve their dependencies on first use.
    private static func makeContainer() -> Container {
        let container = Container()
        let features: [(Container) -> Void] = [
            IdentityFeature.register, PlacesFeature.register, NotificationsFeature.register, FavoritesFeature.register,
            AgendaFeature.register, WalletFeature.register, TicketsFeature.register, ReservationsFeature.register,
            EventsFeature.register, DiningFeature.register, ParkingFeature.register, TransitFeature.register,
            LibraryFeature.register, ReportIssueFeature.register, SearchFeature.register, HomeFeature.register,
        ]
        features.forEach { $0(container) }
        SyntheticFeatures.register(in: container)
        return container
    }
}
