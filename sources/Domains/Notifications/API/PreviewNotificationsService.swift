#if DEBUG
import CoreModels
import Foundation

extension CityNotification {
    public static let previewItems = [
        CityNotification(id: "n1", recipientID: "user-preview", title: "Payment received", body: "You paid $2.75 to Metro Line 2.", date: .now.addingTimeInterval(-600), category: .payment, sourceDomain: "Wallet", isRead: false),
        CityNotification(id: "n2", recipientID: "user-preview", title: "Street cleaning tomorrow", body: "Move cars off Lantern Street before 8 AM.", date: .now.addingTimeInterval(-86_400), category: .cityAlert, sourceDomain: "City", isRead: true),
    ]
}

public struct PreviewNotificationsService: NotificationsService {
    public init() {}

    public func inbox() async throws -> [CityNotification] { CityNotification.previewItems }
    public func unreadCount() async throws -> Int { 1 }
    public func markRead(id: String) async throws {}
    public func markAllRead() async throws {}
    public func delete(id: String) async throws {}

    public func post(_ draft: NotificationDraft) async throws -> CityNotification {
        CityNotification(id: "preview", recipientID: "user-preview", title: draft.title, body: draft.body, date: draft.deliverAt ?? .now, category: draft.category, sourceDomain: draft.sourceDomain, isRead: false)
    }

    public func preferences() async throws -> NotificationPreferences { NotificationPreferences() }
    public func update(preferences: NotificationPreferences) async throws {}

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Inbox", detail: "1 unread")
    }
}
#endif
