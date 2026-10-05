import Agenda
import CoreKit
import DI
import Identity
import Notifications
import SwiftUI
import Wallet

public enum TicketsFeature {
    public static func register(in container: Container) {
        container.registerShared((any TicketsService).self) {
            LiveTicketsService(
                repository: BundleTicketsRepository(loader: MockDataLoader()),
                identity: container.resolve((any IdentityService).self),
                notifications: container.resolve((any NotificationsService).self),
                agenda: container.resolve((any AgendaService).self)
            )
        }
        container.register(TicketsEntryPoints.self) {
            TicketsEntryPoints(
                purchase: { event in
                    AnyView(PurchaseScreen(
                        event: event,
                        service: container.resolve((any TicketsService).self),
                        wallet: container.resolve(WalletEntryPoints.self)
                    ))
                },
                myTickets: { AnyView(MyTicketsScreen(service: container.resolve((any TicketsService).self))) }
            )
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        MyTicketsScreen(service: container.resolve((any TicketsService).self))
    }
}
