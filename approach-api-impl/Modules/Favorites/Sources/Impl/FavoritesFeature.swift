import CoreKit
import DI
import FavoritesAPI
import IdentityAPI
import SwiftUI

public enum FavoritesFeature {
    public static func register(in container: Container) {
        container.registerShared((any FavoritesService).self) {
            LiveFavoritesService(
                repository: BundleFavoritesRepository(loader: MockDataLoader()),
                identity: container.resolve((any IdentityService).self)
            )
        }
        container.register(FavoritesEntryPoints.self) {
            FavoritesEntryPoints(
                toggleButton: { draft in AnyView(FavoriteToggleButton(draft: draft, service: container.resolve((any FavoritesService).self))) },
                list: { AnyView(FavoritesScreen(service: container.resolve((any FavoritesService).self))) }
            )
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        FavoritesScreen(service: container.resolve((any FavoritesService).self))
    }
}
