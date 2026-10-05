import CoreKit
import DI
import Favorites
import Identity
import Places
import SwiftUI
import Wallet

public enum TransitFeature {
    public static func register(in container: Container) {
        container.registerShared((any TransitService).self) {
            LiveTransitService(
                repository: BundleTransitRepository(loader: MockDataLoader()),
                identity: container.resolve((any IdentityService).self),
                wallet: container.resolve((any WalletService).self)
            )
        }
        container.register(TransitEntryPoints.self) {
            TransitEntryPoints { stopID in
                AnyView(StopLookupScreen(stopID: stopID, service: container.resolve((any TransitService).self), ui: ui(container)))
            }
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        TransitScreen(service: container.resolve((any TransitService).self), ui: ui(container))
    }

    private static func ui(_ container: Container) -> TransitUI {
        TransitUI(places: container.resolve(PlacesEntryPoints.self), favorites: container.resolve(FavoritesEntryPoints.self))
    }
}
