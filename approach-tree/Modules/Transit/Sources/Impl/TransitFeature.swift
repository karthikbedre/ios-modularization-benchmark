import DI
import Map
import SwiftUI
import Wallet

public enum TransitFeature {
    public static func register(in container: Container) {
        container.register((any TransitService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        TransitScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveTransitService {
        LiveTransitService(wallet: container.resolve(), map: container.resolve())
    }
}
