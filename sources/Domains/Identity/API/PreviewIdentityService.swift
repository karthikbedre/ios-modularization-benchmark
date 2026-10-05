#if DEBUG
import CoreModels
import Foundation

extension UserProfile {
    public static let preview = UserProfile(
        id: "user-preview",
        fullName: "Avery Morgan",
        email: "avery@example.com",
        phone: "555-0100",
        residentID: "CIV-000001",
        address: Address(street: "12 Harbor Way", district: "Old Town", postalCode: "10001"),
        memberSince: Date(timeIntervalSince1970: 1_600_000_000)
    )
}

public struct PreviewIdentityService: IdentityService {
    public init() {}

    public func currentUser() async throws -> UserProfile { .preview }

    public func update(_ update: ProfileUpdate) async throws -> UserProfile {
        var profile = UserProfile.preview
        profile.fullName = update.fullName
        profile.email = update.email
        profile.phone = update.phone
        return profile
    }

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Profile", detail: UserProfile.preview.fullName)
    }
}
#endif
