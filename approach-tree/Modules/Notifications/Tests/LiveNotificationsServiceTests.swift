@testable import Notifications
import Notifications
import Testing

struct LiveNotificationsServiceTests {
    @Test func inboxShowsOnlyDeliveredNotificationsForTheResidentNewestFirst() async throws {
        let service = NotificationsFixtures.service(repository: NotificationsFixtures.repository())

        let inbox = try await service.inbox()

        #expect(inbox.map(\.id) == ["today", "week", "old"])
        #expect(try await service.unreadCount() == 2)
    }

    @Test func postDeliversNowAndUnread() async throws {
        let repository = NotificationsFixtures.repository()
        let service = NotificationsFixtures.service(repository: repository)

        let posted = try await service.post(NotificationDraft(title: "  Paid  ", body: "You paid", category: .payment, sourceDomain: "Wallet"))

        #expect(posted.title == "Paid")
        #expect(posted.date == NotificationsFixtures.now)
        #expect(!posted.isRead)
        #expect(try await service.inbox().first?.id == "n-new")
    }

    @Test func scheduledPostStaysOutOfInboxUntilDelivery() async throws {
        let service = NotificationsFixtures.service(repository: NotificationsFixtures.repository())

        try await service.post(NotificationDraft(title: "Reminder", body: "", category: .reminder, sourceDomain: "Calendar", deliverAt: NotificationsFixtures.now.addingTimeInterval(3600)))

        #expect(try await !service.inbox().contains { $0.id == "n-new" })
    }

    @Test func mutedCategoryArrivesAlreadyRead() async throws {
        let service = NotificationsFixtures.service(repository: NotificationsFixtures.repository(muted: [.payment]))

        let posted = try await service.post(NotificationDraft(title: "Paid", body: "", category: .payment, sourceDomain: "Wallet"))

        #expect(posted.isRead)
    }

    @Test func emptyTitleIsRejected() async {
        let service = NotificationsFixtures.service(repository: NotificationsFixtures.repository())

        await #expect(throws: NotificationsError.emptyTitle) {
            try await service.post(NotificationDraft(title: " ", body: "", category: .payment, sourceDomain: "Wallet"))
        }
    }

    @Test func markAllReadOnlyTouchesDeliveredNotifications() async throws {
        let repository = NotificationsFixtures.repository()
        let service = NotificationsFixtures.service(repository: repository)

        try await service.markAllRead()

        #expect(try await service.unreadCount() == 0)
        let snapshot = await repository.snapshot
        #expect(snapshot.notifications.first { $0.id == "future" }?.isRead == false)
        #expect(snapshot.notifications.first { $0.id == "someone-else" }?.isRead == false)
    }

    @Test func markReadAndDeleteRejectUnknownIDs() async {
        let service = NotificationsFixtures.service(repository: NotificationsFixtures.repository())

        await #expect(throws: NotificationsError.notFound) { try await service.markRead(id: "missing") }
        await #expect(throws: NotificationsError.notFound) { try await service.delete(id: "missing") }
    }

    @Test func summaryReportsUnreadCount() async {
        let service = NotificationsFixtures.service(repository: NotificationsFixtures.repository())

        #expect(await service.summary().detail == "2 unread")
    }
}
