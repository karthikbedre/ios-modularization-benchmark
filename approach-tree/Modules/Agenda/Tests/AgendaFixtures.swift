@testable import Agenda
import Agenda
import CoreModels
import Foundation
import Identity
import Notifications

enum AgendaFixtures {
    /// Monday 2026-10-05 12:00 UTC.
    static let now = Date(timeIntervalSince1970: 1_791_201_600)

    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func entry(_ id: String, startsInHours hours: Double, durationHours: Double = 1, owner: String = "user-1", sourceItemID: String? = nil) -> CalendarEntry {
        let start = now.addingTimeInterval(hours * 3600)
        return CalendarEntry(id: id, ownerID: owner, title: id, start: start, end: start.addingTimeInterval(durationHours * 3600),
                             location: nil, sourceDomain: "Test", sourceItemID: sourceItemID, reminder: .none)
    }

    static let entries = [
        entry("past", startsInHours: -30),
        entry("soon", startsInHours: 2),
        entry("tomorrow", startsInHours: 26, sourceItemID: "ticket-1"),
        entry("next-week", startsInHours: 24 * 8),
        entry("other-user", startsInHours: 3, owner: "user-2"),
    ]

    static func service(repository: InMemoryAgendaRepository, notifications: RecordingNotificationsService = RecordingNotificationsService()) -> LiveAgendaService {
        LiveAgendaService(repository: repository, identity: StubIdentityService(), notifications: notifications, dates: .fixed(now), makeID: { "cal-new" })
    }
}

struct StubIdentityService: IdentityService {
    func currentUser() async throws -> UserProfile {
        UserProfile(id: "user-1", fullName: "Sam Lee", email: "sam@example.com", phone: "5550199", residentID: "CIV-1",
                    address: Address(street: "1 Main", district: "Center", postalCode: "10000"), memberSince: AgendaFixtures.now)
    }

    func update(_ update: ProfileUpdate) async throws -> UserProfile { try await currentUser() }
    func summary() async -> DomainSummary { DomainSummary(title: "Profile", detail: "") }
}

actor RecordingNotificationsService: NotificationsService {
    private(set) var posted: [NotificationDraft] = []

    func inbox() async throws -> [CityNotification] { [] }
    func unreadCount() async throws -> Int { 0 }
    func markRead(id: String) async throws {}
    func markAllRead() async throws {}
    func delete(id: String) async throws {}

    func post(_ draft: NotificationDraft) async throws -> CityNotification {
        posted.append(draft)
        return CityNotification(id: "n", recipientID: "user-1", title: draft.title, body: draft.body, date: draft.deliverAt ?? .now, category: draft.category, sourceDomain: draft.sourceDomain, isRead: false)
    }

    func preferences() async throws -> NotificationPreferences { NotificationPreferences() }
    func update(preferences: NotificationPreferences) async throws {}
    func summary() async -> DomainSummary { DomainSummary(title: "Inbox", detail: "") }
}
