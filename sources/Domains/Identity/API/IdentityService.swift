import CoreModels
import SwiftUI

public protocol IdentityService: SummaryProviding {
    func currentUser() async throws -> UserProfile
    func update(_ update: ProfileUpdate) async throws -> UserProfile
}

/// Screens other domains can present without importing the Identity implementation.
public struct IdentityEntryPoints: Sendable {
    public var profile: @MainActor @Sendable () -> AnyView

    public init(profile: @escaping @MainActor @Sendable () -> AnyView) {
        self.profile = profile
    }
}
