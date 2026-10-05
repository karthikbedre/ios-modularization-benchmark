import CoreKit
@testable import Identity
import Testing

struct BundleFixtureTests {
    @Test func bundledProfileDecodes() async throws {
        let repository = BundleIdentityRepository(loader: MockDataLoader(latency: .none))

        let profile = try await repository.loadProfile()

        #expect(profile.residentID == "CIV-204518")
    }
}
