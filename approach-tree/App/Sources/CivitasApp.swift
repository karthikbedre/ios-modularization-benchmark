import DI
import Dining
import Events
import Home
import Identity
import Library
import Map
import Notifications
import Parking
import ReportIssue
import Reservations
import SwiftUI
import Tickets
import Transit
import Wallet

@main
struct CivitasApp: App {
    private let container = CivitasApp.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }

    private static func makeContainer() -> Container {
        let container = Container()
        IdentityFeature.register(in: container)
        MapFeature.register(in: container)
        NotificationsFeature.register(in: container)
        WalletFeature.register(in: container)
        TicketsFeature.register(in: container)
        EventsFeature.register(in: container)
        ParkingFeature.register(in: container)
        TransitFeature.register(in: container)
        ReservationsFeature.register(in: container)
        DiningFeature.register(in: container)
        LibraryFeature.register(in: container)
        ReportIssueFeature.register(in: container)
        HomeFeature.register(in: container)
        return container
    }
}
