import CoreKit
import DesignSystem
import IdentityAPI
import SwiftUI

struct ProfileScreen: View {
    @State private var viewModel: ProfileViewModel
    @State private var isEditing = false

    init(service: any IdentityService) {
        _viewModel = State(initialValue: ProfileViewModel(service: service))
    }

    var body: some View {
        AsyncContentView(state: viewModel.state, retry: viewModel.load) { profile in
            List {
                Section {
                    ProfileHeader(profile: profile)
                }
                Section("Contact") {
                    KeyValueRow("Email", value: profile.email)
                    KeyValueRow("Phone", value: profile.phone)
                }
                Section("Residency") {
                    KeyValueRow("Resident ID", value: profile.residentID)
                    KeyValueRow("Address", value: profile.address.singleLine)
                    KeyValueRow("Member since", value: profile.memberSince.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            Button("Edit") {
                viewModel.beginEditing()
                isEditing = true
            }
            .disabled(viewModel.state.value == nil)
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                EditProfileScreen(viewModel: viewModel)
            }
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
    }
}

private struct ProfileHeader: View {
    let profile: UserProfile

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Text(profile.initials)
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
                .background(Palette.accent.opacity(0.2), in: Circle())
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(profile.fullName)
                    .font(.headline)
                Text(profile.address.district)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.small)
    }
}

#Preview {
    NavigationStack {
        ProfileScreen(service: PreviewIdentityService())
    }
}
