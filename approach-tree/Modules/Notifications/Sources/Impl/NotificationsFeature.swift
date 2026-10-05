import CoreKit
import DI
import Identity
import SwiftUI

public enum NotificationsFeature {
    public static func register(in container: Container) {
        container.registerShared((any NotificationsService).self) {
            LiveNotificationsService(
                repository: BundleNotificationsRepository(loader: MockDataLoader()),
                identity: container.resolve((any IdentityService).self)
            )
        }
        container.register(NotificationsEntryPoints.self) {
            NotificationsEntryPoints { AnyView(InboxScreen(service: container.resolve((any NotificationsService).self))) }
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        InboxScreen(service: container.resolve((any NotificationsService).self))
    }
}
