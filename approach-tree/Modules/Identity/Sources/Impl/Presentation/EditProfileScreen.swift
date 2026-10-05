import DesignSystem
import SwiftUI

struct EditProfileScreen: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Name") {
                TextField("Full name", text: $viewModel.draft.fullName)
                    .textContentType(.name)
            }
            Section("Contact") {
                TextField("Email", text: $viewModel.draft.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Phone", text: $viewModel.draft.phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }
            if let message = viewModel.validationMessage {
                Section {
                    Text(message)
                        .foregroundStyle(Palette.negative)
                }
            }
        }
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        if await viewModel.save() { dismiss() }
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileScreen(viewModel: ProfileViewModel(service: PreviewIdentityService()))
    }
}
