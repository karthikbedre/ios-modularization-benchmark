import CoreKit
import CoreModels
import Foundation
import IdentityAPI
import NotificationsAPI

public struct LiveNotificationsService: NotificationsService {
    private let repository: any NotificationsRepository
    private let identity: any IdentityService
    private let dates: DateProvider
    private let makeID: @Sendable () -> String

    init(
        repository: any NotificationsRepository,
        identity: any IdentityService,
        dates: DateProvider = .live,
        makeID: @escaping @Sendable () -> String = { "n-\(UUID().uuidString.prefix(8))" }
    ) {
        self.repository = repository
        self.identity = identity
        self.dates = dates
        self.makeID = makeID
    }

    public func inbox() async throws -> [CityNotification] {
        let recipientID = try await identity.currentUser().id
        let now = dates.now
        return try await repository.load().notifications
            .filter { $0.recipientID == recipientID && $0.date <= now }
            .sorted { $0.date > $1.date }
    }

    public func unreadCount() async throws -> Int {
        try await inbox().count { !$0.isRead }
    }

    public func markRead(id: String) async throws {
        try await repository.update { snapshot in
            guard let index = snapshot.notifications.firstIndex(where: { $0.id == id }) else {
                throw NotificationsError.notFound
            }
            snapshot.notifications[index].isRead = true
        }
    }

    public func markAllRead() async throws {
        let delivered = Set(try await inbox().map(\.id))
        try await repository.update { snapshot in
            for index in snapshot.notifications.indices where delivered.contains(snapshot.notifications[index].id) {
                snapshot.notifications[index].isRead = true
            }
        }
    }

    public func delete(id: String) async throws {
        try await repository.update { snapshot in
            guard snapshot.notifications.contains(where: { $0.id == id }) else {
                throw NotificationsError.notFound
            }
            snapshot.notifications.removeAll { $0.id == id }
        }
    }

    @discardableResult
    public func post(_ draft: NotificationDraft) async throws -> CityNotification {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw NotificationsError.emptyTitle }
        let recipientID = try await identity.currentUser().id
        let id = makeID()
        let date = draft.deliverAt ?? dates.now

        return try await repository.update { snapshot in
            let notification = CityNotification(
                id: id,
                recipientID: recipientID,
                title: title,
                body: draft.body,
                date: date,
                category: draft.category,
                sourceDomain: draft.sourceDomain,
                isRead: snapshot.preferences.mutedCategories.contains(draft.category)
            )
            snapshot.notifications.append(notification)
            return notification
        }
    }

    public func preferences() async throws -> NotificationPreferences {
        try await repository.load().preferences
    }

    public func update(preferences: NotificationPreferences) async throws {
        try await repository.update { $0.preferences = preferences }
    }

    public func summary() async -> DomainSummary {
        guard let unread = try? await unreadCount() else {
            return DomainSummary(title: "Inbox", detail: "Unavailable")
        }
        return DomainSummary(title: "Inbox", detail: unread == 0 ? "All caught up" : "\(unread) unread")
    }
}
