import AgendaAPI
import CoreKit
import DI
import FavoritesAPI
import IdentityAPI
import LibraryAPI
import NotificationsAPI
import PlacesAPI
import SwiftUI

public enum LibraryFeature {
    public static func register(in container: Container) {
        container.registerShared((any LibraryService).self) {
            LiveLibraryService(
                repository: BundleLibraryRepository(loader: MockDataLoader()),
                identity: container.resolve((any IdentityService).self),
                notifications: container.resolve((any NotificationsService).self),
                agenda: container.resolve((any AgendaService).self)
            )
        }
        container.register(LibraryEntryPoints.self) {
            LibraryEntryPoints { bookID in
                AnyView(BookDetailScreen(bookID: bookID, service: container.resolve((any LibraryService).self), ui: ui(container)))
            }
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        LibraryScreen(service: container.resolve((any LibraryService).self), ui: ui(container))
    }

    private static func ui(_ container: Container) -> LibraryUI {
        LibraryUI(places: container.resolve(PlacesEntryPoints.self), favorites: container.resolve(FavoritesEntryPoints.self))
    }
}
