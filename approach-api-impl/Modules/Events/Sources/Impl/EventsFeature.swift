import DI
import EventsAPI
import MapAPI
import SwiftUI
import TicketsAPI

public enum EventsFeature {
    public static func register(in container: Container) {
        container.register((any EventsService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        EventsScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveEventsService {
        LiveEventsService(tickets: container.resolve(), map: container.resolve())
    }
}
