import DesignSystem
import NotificationsAPI
import SwiftUI

struct NotificationDetailScreen: View {
    let notification: CityNotification

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Label(notification.category.title, systemImage: notification.category.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(notification.category.tint)
                Text(notification.title)
                    .font(.title2.weight(.semibold))
                Text(notification.date.formatted(date: .long, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(notification.body)
                    .font(.body)
                Divider()
                KeyValueRow("From", value: notification.sourceDomain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.large)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationDetailScreen(notification: CityNotification.previewItems[0])
    }
}
