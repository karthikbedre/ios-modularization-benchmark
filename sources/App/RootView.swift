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

struct RootView: View {
    let container: Container

    var body: some View {
        TabView {
            NavigationStack {
                HomeFeature.makeScreen(container: container)
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                List {
                    NavigationLink("Identity") { IdentityFeature.makeScreen(container: container) }
                    NavigationLink("Map") { MapFeature.makeScreen(container: container) }
                    NavigationLink("Notifications") { NotificationsFeature.makeScreen(container: container) }
                    NavigationLink("Wallet") { WalletFeature.makeScreen(container: container) }
                    NavigationLink("Tickets") { TicketsFeature.makeScreen(container: container) }
                    NavigationLink("Events") { EventsFeature.makeScreen(container: container) }
                    NavigationLink("Parking") { ParkingFeature.makeScreen(container: container) }
                    NavigationLink("Transit") { TransitFeature.makeScreen(container: container) }
                    NavigationLink("Reservations") { ReservationsFeature.makeScreen(container: container) }
                    NavigationLink("Dining") { DiningFeature.makeScreen(container: container) }
                    NavigationLink("Library") { LibraryFeature.makeScreen(container: container) }
                    NavigationLink("ReportIssue") { ReportIssueFeature.makeScreen(container: container) }
                }
                .navigationTitle("Services")
            }
            .tabItem { Label("Services", systemImage: "square.grid.2x2") }
        }
    }
}
