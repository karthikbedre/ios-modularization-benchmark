@testable import Identity
import Identity
import Testing

struct LiveIdentityServiceTests {
    private let repository = InMemoryIdentityRepository(profile: .fixture)
    private var service: LiveIdentityService { LiveIdentityService(repository: repository) }

    @Test func updateNormalizesAndPersistsTheProfile() async throws {
        let updated = try await service.update(ProfileUpdate(fullName: "  Sam Lee-Park ", email: " SAM@Example.com", phone: "(555) 0199-22"))

        #expect(updated.fullName == "Sam Lee-Park")
        #expect(updated.email == "sam@example.com")
        #expect(updated.phone == "5550199-22")
        #expect(await repository.profile == updated)
    }

    @Test(arguments: [
        (ProfileUpdate(fullName: " ", email: "sam@example.com", phone: "5550199"), IdentityError.emptyName),
        (ProfileUpdate(fullName: "Sam", email: "sam@example", phone: "5550199"), IdentityError.invalidEmail),
        (ProfileUpdate(fullName: "Sam", email: "@example.com", phone: "5550199"), IdentityError.invalidEmail),
        (ProfileUpdate(fullName: "Sam", email: "sam@example.com", phone: "555"), IdentityError.invalidPhone),
    ])
    func updateRejectsInvalidInput(update: ProfileUpdate, expected: IdentityError) async {
        await #expect(throws: expected) {
            try await service.update(update)
        }
        #expect(await repository.profile == .fixture)
    }

    @Test func summaryShowsNameAndResidentID() async {
        let summary = await service.summary()

        #expect(summary.detail == "Sam Lee · CIV-100200")
    }
}
