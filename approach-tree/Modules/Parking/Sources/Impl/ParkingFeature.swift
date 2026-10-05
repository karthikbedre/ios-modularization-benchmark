import CoreKit
import DI
import Identity
import Notifications
import Places
import SwiftUI
import Wallet

public enum ParkingFeature {
    public static func register(in container: Container) {
        container.registerShared((any ParkingService).self) {
            LiveParkingService(
                repository: BundleParkingRepository(loader: MockDataLoader()),
                identity: container.resolve((any IdentityService).self),
                wallet: container.resolve((any WalletService).self),
                notifications: container.resolve((any NotificationsService).self)
            )
        }
        container.register(ParkingEntryPoints.self) {
            ParkingEntryPoints { AnyView(makeScreen(container: container)) }
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        ParkingScreen(service: container.resolve((any ParkingService).self), places: container.resolve(PlacesEntryPoints.self))
    }
}
