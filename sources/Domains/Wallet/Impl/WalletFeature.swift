import CoreKit
import DI
import IdentityAPI
import NotificationsAPI
import SwiftUI
import WalletAPI

public enum WalletFeature {
    public static func register(in container: Container) {
        container.registerShared((any WalletService).self) {
            LiveWalletService(
                repository: BundleWalletRepository(loader: MockDataLoader()),
                identity: container.resolve((any IdentityService).self),
                notifications: container.resolve((any NotificationsService).self)
            )
        }
        container.register(WalletEntryPoints.self) {
            WalletEntryPoints { request, onComplete in
                AnyView(CheckoutScreen(request: request, service: container.resolve((any WalletService).self), onComplete: onComplete))
            }
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        WalletHomeScreen(service: container.resolve((any WalletService).self))
    }
}
