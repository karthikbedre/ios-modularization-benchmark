import DI
import MapAPI
import SwiftUI

public enum MapFeature {
    public static func register(in container: Container) {
        container.register((any MapService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        MapScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveMapService {
        LiveMapService()
    }
}
