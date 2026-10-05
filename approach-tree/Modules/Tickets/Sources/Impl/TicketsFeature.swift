import DI
import Identity
import SwiftUI
import Wallet

public enum TicketsFeature {
    public static func register(in container: Container) {
        container.register((any TicketsService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        TicketsScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveTicketsService {
        LiveTicketsService(wallet: container.resolve(), identity: container.resolve())
    }
}
