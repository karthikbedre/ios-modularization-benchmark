import CoreKit
import DesignSystem
import SwiftUI

struct NotificationSettingsScreen: View {
    private let service: any NotificationsService
    @State private var preferences: LoadState<NotificationPreferences> = .idle
    @Environment(\.dismiss) private var dismiss

    init(service: any NotificationsService) {
        self.service = service
    }

    var body: some View {
        AsyncContentView(state: preferences, retry: load) { current in
            Form {
                Section {
                    ForEach(NotificationCategory.allCases, id: \.self) { category in
                        Toggle(isOn: binding(for: category, in: current)) {
                            Label(category.title, systemImage: category.systemImage)
                        }
                    }
                } footer: {
                    Text("Muted categories still reach your inbox, but arrive already read.")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Done") { dismiss() }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            preferences = .loaded(try await service.preferences())
        } catch {
            preferences = .failed("Settings could not be loaded.")
        }
    }

    private func binding(for category: NotificationCategory, in current: NotificationPreferences) -> Binding<Bool> {
        Binding {
            !current.mutedCategories.contains(category)
        } set: { isOn in
            var updated = current
            if isOn {
                updated.mutedCategories.remove(category)
            } else {
                updated.mutedCategories.insert(category)
            }
            preferences = .loaded(updated)
            Task { try? await service.update(preferences: updated) }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsScreen(service: PreviewNotificationsService())
    }
}
