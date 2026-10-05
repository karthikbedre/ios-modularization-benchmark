import CoreModels

public struct LiveIdentityService: IdentityService {
    private let repository: any IdentityRepository

    init(repository: any IdentityRepository) {
        self.repository = repository
    }

    public func currentUser() async throws -> UserProfile {
        try await repository.loadProfile()
    }

    public func update(_ update: ProfileUpdate) async throws -> UserProfile {
        let valid = try ProfileValidator.validate(update)
        var profile = try await repository.loadProfile()
        profile.fullName = valid.fullName
        profile.email = valid.email
        profile.phone = valid.phone
        try await repository.save(profile)
        return profile
    }

    public func summary() async -> DomainSummary {
        guard let profile = try? await currentUser() else {
            return DomainSummary(title: "Profile", detail: "Sign in to see your details")
        }
        return DomainSummary(title: "Profile", detail: "\(profile.fullName) · \(profile.residentID)")
    }
}
