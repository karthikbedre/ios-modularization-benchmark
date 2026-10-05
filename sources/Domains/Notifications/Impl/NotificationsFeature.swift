import DI
import IdentityAPI
import NotificationsAPI
import SwiftUI

public enum NotificationsFeature {
    public static func register(in container: Container) {
        container.register((any NotificationsService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        NotificationsScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveNotificationsService {
        LiveNotificationsService(identity: container.resolve())
    }
}
