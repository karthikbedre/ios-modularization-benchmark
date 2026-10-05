import DI
import Map
import SwiftUI
import Wallet

public enum ParkingFeature {
    public static func register(in container: Container) {
        container.register((any ParkingService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        ParkingScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveParkingService {
        LiveParkingService(wallet: container.resolve(), map: container.resolve())
    }
}
