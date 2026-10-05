import CoreKit
import DI
import IdentityAPI
import SwiftUI

public enum IdentityFeature {
    public static func register(in container: Container) {
        container.registerShared((any IdentityService).self) {
            LiveIdentityService(repository: BundleIdentityRepository(loader: MockDataLoader()))
        }
        container.register(IdentityEntryPoints.self) {
            IdentityEntryPoints { AnyView(ProfileScreen(service: container.resolve((any IdentityService).self))) }
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        ProfileScreen(service: container.resolve((any IdentityService).self))
    }
}
