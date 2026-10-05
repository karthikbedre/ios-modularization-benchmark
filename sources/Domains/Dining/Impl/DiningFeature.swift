import DI
import DiningAPI
import MapAPI
import ReservationsAPI
import SwiftUI

public enum DiningFeature {
    public static func register(in container: Container) {
        container.register((any DiningService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        DiningScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveDiningService {
        LiveDiningService(reservations: container.resolve(), map: container.resolve())
    }
}
