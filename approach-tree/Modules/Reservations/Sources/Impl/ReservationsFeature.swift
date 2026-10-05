import Agenda
import CoreKit
import DI
import Identity
import Notifications
import SwiftUI

public enum ReservationsFeature {
    public static func register(in container: Container) {
        container.registerShared((any ReservationsService).self) {
            LiveReservationsService(
                repository: BundleReservationsRepository(loader: MockDataLoader()),
                identity: container.resolve((any IdentityService).self),
                notifications: container.resolve((any NotificationsService).self),
                agenda: container.resolve((any AgendaService).self)
            )
        }
        container.register(ReservationsEntryPoints.self) {
            ReservationsEntryPoints(
                booking: { venue in AnyView(BookingScreen(venue: venue, service: container.resolve((any ReservationsService).self))) },
                myReservations: { AnyView(ReservationsScreen(service: container.resolve((any ReservationsService).self))) }
            )
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        ReservationsScreen(service: container.resolve((any ReservationsService).self))
    }
}
