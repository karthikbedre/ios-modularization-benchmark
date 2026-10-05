import DI
import IdentityAPI
import SwiftUI
import WalletAPI

public enum WalletFeature {
    public static func register(in container: Container) {
        container.register((any WalletService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        WalletScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveWalletService {
        LiveWalletService(identity: container.resolve())
    }
}
