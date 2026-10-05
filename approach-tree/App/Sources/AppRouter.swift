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

/// The one place that knows every feature's root screen.
@MainActor
struct AppRouter {
    let container: Container

    func view(for section: HomeSection) -> AnyView {
        switch section {
        case .profile: AnyView(IdentityFeature.makeScreen(container: container))
        case .inbox: AnyView(NotificationsFeature.makeScreen(container: container))
        case .agenda: AnyView(AgendaFeature.makeScreen(container: container))
        case .saved: AnyView(FavoritesFeature.makeScreen(container: container))
        case .wallet: AnyView(WalletFeature.makeScreen(container: container))
        case .tickets: AnyView(TicketsFeature.makeScreen(container: container))
        case .reservations: AnyView(ReservationsFeature.makeScreen(container: container))
        case .events: AnyView(EventsFeature.makeScreen(container: container))
        case .dining: AnyView(DiningFeature.makeScreen(container: container))
        case .parking: AnyView(ParkingFeature.makeScreen(container: container))
        case .transit: AnyView(TransitFeature.makeScreen(container: container))
        case .library: AnyView(LibraryFeature.makeScreen(container: container))
        case .reports: AnyView(ReportIssueFeature.makeScreen(container: container))
        case .search: AnyView(SearchFeature.makeScreen(container: container))
        }
    }

    var places: AnyView {
        AnyView(PlacesFeature.makeScreen(container: container))
    }
}
