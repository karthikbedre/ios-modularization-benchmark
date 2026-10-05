import CoreKit
import Foundation
import IdentityAPI

protocol IdentityRepository: Sendable {
    func loadProfile() async throws -> UserProfile
    func save(_ profile: UserProfile) async throws
}

/// Serves the bundled fixture and keeps edits in memory for the session.
actor BundleIdentityRepository: IdentityRepository {
    private let loader: MockDataLoader
    private var cached: UserProfile?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func loadProfile() async throws -> UserProfile {
        if let cached { return cached }
        let profile = try await loader.load(UserProfile.self, resource: "identity", in: .module)
        cached = profile
        return profile
    }

    func save(_ profile: UserProfile) async throws {
        cached = profile
    }
}

actor InMemoryIdentityRepository: IdentityRepository {
    private(set) var profile: UserProfile

    init(profile: UserProfile) {
        self.profile = profile
    }

    func loadProfile() async throws -> UserProfile { profile }

    func save(_ profile: UserProfile) async throws {
        self.profile = profile
    }
}
