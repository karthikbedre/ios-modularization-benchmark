import CoreKit
import IdentityAPI
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    private(set) var state: LoadState<UserProfile> = .idle
    var draft = ProfileUpdate(fullName: "", email: "", phone: "")
    private(set) var validationMessage: String?
    private(set) var isSaving = false

    private let service: any IdentityService

    init(service: any IdentityService) {
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            let profile = try await service.currentUser()
            state = .loaded(profile)
            draft = ProfileUpdate(profile)
        } catch {
            state = .failed("Your profile could not be loaded.")
        }
    }

    func beginEditing() {
        if let profile = state.value {
            draft = ProfileUpdate(profile)
        }
        validationMessage = nil
    }

    /// Returns true when the profile was saved and the editor can close.
    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let profile = try await service.update(draft)
            state = .loaded(profile)
            validationMessage = nil
            return true
        } catch let error as IdentityError {
            validationMessage = error.message
        } catch {
            validationMessage = "Your changes could not be saved."
        }
        return false
    }
}
