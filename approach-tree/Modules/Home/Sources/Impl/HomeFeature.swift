import DI
import Dining
import Events
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

public enum HomeFeature {
    public static func register(in container: Container) {
        container.register((any HomeService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        HomeScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveHomeService {
        LiveHomeService(identity: container.resolve(), map: container.resolve(), notifications: container.resolve(), wallet: container.resolve(), tickets: container.resolve(), events: container.resolve(), parking: container.resolve(), transit: container.resolve(), reservations: container.resolve(), dining: container.resolve(), library: container.resolve(), reportIssue: container.resolve())
    }
}
