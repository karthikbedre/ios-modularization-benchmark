import CoreModels
import Foundation
import Identity
@testable import Notifications
import Notifications

enum NotificationsFixtures {
    /// Monday 2026-10-05 12:00 UTC.
    static let now = Date(timeIntervalSince1970: 1_791_201_600)

    static func notification(_ id: String, hoursAgo: Double, category: NotificationCategory = .cityAlert, isRead: Bool = false, recipientID: String = "user-1") -> CityNotification {
        CityNotification(id: id, recipientID: recipientID, title: "Title \(id)", body: "Body", date: now.addingTimeInterval(-hoursAgo * 3600), category: category, sourceDomain: "Test", isRead: isRead)
    }

    static let notifications = [
        notification("today", hoursAgo: 2, category: .payment),
        notification("week", hoursAgo: 50, category: .booking, isRead: true),
        notification("old", hoursAgo: 24 * 20, category: .library),
        notification("future", hoursAgo: -48, category: .reminder),
        notification("someone-else", hoursAgo: 1, recipientID: "user-2"),
    ]

    static func service(repository: InMemoryNotificationsRepository) -> LiveNotificationsService {
        LiveNotificationsService(repository: repository, identity: StubIdentityService(), dates: .fixed(now), makeID: { "n-new" })
    }

    static func repository(muted: Set<NotificationCategory> = []) -> InMemoryNotificationsRepository {
        InMemoryNotificationsRepository(snapshot: NotificationsSnapshot(notifications: notifications, preferences: NotificationPreferences(mutedCategories: muted)))
    }
}

struct StubIdentityService: IdentityService {
    func currentUser() async throws -> UserProfile {
        UserProfile(id: "user-1", fullName: "Sam Lee", email: "sam@example.com", phone: "5550199", residentID: "CIV-1",
                    address: Address(street: "1 Main", district: "Center", postalCode: "10000"), memberSince: NotificationsFixtures.now)
    }

    func update(_ update: ProfileUpdate) async throws -> UserProfile { try await currentUser() }

    func summary() async -> DomainSummary { DomainSummary(title: "Profile", detail: "Sam Lee") }
}
