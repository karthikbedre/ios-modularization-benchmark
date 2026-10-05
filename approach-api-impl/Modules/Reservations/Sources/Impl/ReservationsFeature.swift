import DI
import IdentityAPI
import NotificationsAPI
import ReservationsAPI
import SwiftUI

public enum ReservationsFeature {
    public static func register(in container: Container) {
        container.register((any ReservationsService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        ReservationsScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveReservationsService {
        LiveReservationsService(identity: container.resolve(), notifications: container.resolve())
    }
}
