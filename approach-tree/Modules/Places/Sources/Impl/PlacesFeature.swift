import CoreKit
import DI
import SwiftUI

public enum PlacesFeature {
    public static func register(in container: Container) {
        container.registerShared((any PlacesService).self) {
            LivePlacesService(repository: BundlePlacesRepository(loader: MockDataLoader()))
        }
        container.register(PlacesEntryPoints.self) {
            PlacesEntryPoints(
                place: { id in AnyView(PlaceLookupScreen(placeID: id, service: container.resolve((any PlacesService).self))) },
                location: { title, point in AnyView(LocationScreen(title: title, point: point)) }
            )
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        PlacesExplorerScreen(service: container.resolve((any PlacesService).self))
    }
}
