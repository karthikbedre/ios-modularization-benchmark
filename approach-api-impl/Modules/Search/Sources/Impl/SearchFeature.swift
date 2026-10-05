import DI
import DiningAPI
import EventsAPI
import LibraryAPI
import PlacesAPI
import SearchAPI
import SwiftUI
import TransitAPI

public enum SearchFeature {
    public static func register(in container: Container) {
        container.registerShared((any SearchService).self) {
            LiveSearchService(
                events: container.resolve((any EventsService).self),
                dining: container.resolve((any DiningService).self),
                library: container.resolve((any LibraryService).self),
                transit: container.resolve((any TransitService).self),
                places: container.resolve((any PlacesService).self)
            )
        }
        container.register(SearchEntryPoints.self) {
            SearchEntryPoints { AnyView(makeScreen(container: container)) }
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        SearchScreen(
            service: container.resolve((any SearchService).self),
            ui: SearchUI(
                events: container.resolve(EventsEntryPoints.self),
                dining: container.resolve(DiningEntryPoints.self),
                library: container.resolve(LibraryEntryPoints.self),
                transit: container.resolve(TransitEntryPoints.self),
                places: container.resolve(PlacesEntryPoints.self)
            )
        )
    }
}
