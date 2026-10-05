import DI
import SwiftUI

public enum IdentityFeature {
    public static func register(in container: Container) {
        container.register((any IdentityService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        IdentityScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveIdentityService {
        LiveIdentityService()
    }
}
