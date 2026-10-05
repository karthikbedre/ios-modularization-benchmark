import DI
import Identity
import Notifications
import SwiftUI

public enum LibraryFeature {
    public static func register(in container: Container) {
        container.register((any LibraryService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        LibraryScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveLibraryService {
        LiveLibraryService(identity: container.resolve(), notifications: container.resolve())
    }
}
