import CoreKit
import DI
import Favorites
import Places
import Reservations
import SwiftUI

public enum DiningFeature {
    public static func register(in container: Container) {
        container.registerShared((any DiningService).self) {
            LiveDiningService(repository: BundleDiningRepository(loader: MockDataLoader()))
        }
        container.register(DiningEntryPoints.self) {
            DiningEntryPoints { restaurantID in
                AnyView(RestaurantLookupScreen(restaurantID: restaurantID, service: container.resolve((any DiningService).self), ui: ui(container)))
            }
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        DiningScreen(service: container.resolve((any DiningService).self), ui: ui(container))
    }

    private static func ui(_ container: Container) -> DiningUI {
        DiningUI(
            places: container.resolve(PlacesEntryPoints.self),
            favorites: container.resolve(FavoritesEntryPoints.self),
            reservations: container.resolve(ReservationsEntryPoints.self)
        )
    }
}
