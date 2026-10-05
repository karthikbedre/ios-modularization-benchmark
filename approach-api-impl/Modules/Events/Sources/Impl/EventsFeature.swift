import AgendaAPI
import CoreKit
import DI
import EventsAPI
import FavoritesAPI
import PlacesAPI
import SwiftUI
import TicketsAPI

public enum EventsFeature {
    public static func register(in container: Container) {
        container.registerShared((any EventsService).self) {
            LiveEventsService(repository: BundleEventsRepository(loader: MockDataLoader()))
        }
        container.register(EventsEntryPoints.self) {
            EventsEntryPoints { eventID in
                AnyView(EventLookupScreen(eventID: eventID, service: container.resolve((any EventsService).self), ui: ui(container)))
            }
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        EventsScreen(service: container.resolve((any EventsService).self), ui: ui(container))
    }

    private static func ui(_ container: Container) -> EventsUI {
        EventsUI(
            places: container.resolve(PlacesEntryPoints.self),
            favorites: container.resolve(FavoritesEntryPoints.self),
            agenda: container.resolve(AgendaEntryPoints.self),
            tickets: container.resolve(TicketsEntryPoints.self)
        )
    }
}
