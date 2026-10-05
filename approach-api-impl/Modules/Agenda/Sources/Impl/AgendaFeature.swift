import AgendaAPI
import CoreKit
import DI
import IdentityAPI
import NotificationsAPI
import SwiftUI

public enum AgendaFeature {
    public static func register(in container: Container) {
        container.registerShared((any AgendaService).self) {
            LiveAgendaService(
                repository: BundleAgendaRepository(loader: MockDataLoader()),
                identity: container.resolve((any IdentityService).self),
                notifications: container.resolve((any NotificationsService).self)
            )
        }
        container.register(AgendaEntryPoints.self) {
            AgendaEntryPoints(
                addButton: { draft in AnyView(AddToAgendaButton(draft: draft, service: container.resolve((any AgendaService).self))) },
                agenda: { AnyView(AgendaScreen(service: container.resolve((any AgendaService).self))) }
            )
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        AgendaScreen(service: container.resolve((any AgendaService).self))
    }
}
