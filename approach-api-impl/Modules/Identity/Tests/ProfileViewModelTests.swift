@testable import Identity
import IdentityAPI
import Testing

@MainActor
struct ProfileViewModelTests {
    private let viewModel = ProfileViewModel(
        service: LiveIdentityService(repository: InMemoryIdentityRepository(profile: .fixture))
    )

    @Test func loadPopulatesStateAndDraft() async {
        await viewModel.load()

        #expect(viewModel.state == .loaded(.fixture))
        #expect(viewModel.draft == ProfileUpdate(.fixture))
    }

    @Test func saveWithInvalidEmailKeepsEditorOpenWithMessage() async {
        await viewModel.load()
        viewModel.draft.email = "not-an-email"

        let saved = await viewModel.save()

        #expect(!saved)
        #expect(viewModel.validationMessage == "Enter a valid email address.")
        #expect(viewModel.state == .loaded(.fixture))
    }

    @Test func successfulSaveUpdatesStateAndClearsMessage() async {
        await viewModel.load()
        viewModel.draft.fullName = "Sam Park"

        let saved = await viewModel.save()

        #expect(saved)
        #expect(viewModel.validationMessage == nil)
        #expect(viewModel.state.value?.fullName == "Sam Park")
    }
}
