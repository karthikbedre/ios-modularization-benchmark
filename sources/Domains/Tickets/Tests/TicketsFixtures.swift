import AgendaAPI
import CoreKit
import CoreModels
import Foundation
import IdentityAPI
import NotificationsAPI
@testable import Tickets
import TicketsAPI
import WalletAPI

/// A clock tests can move forward to expire holds.
final class TestClock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_791_201_600)
    var provider: DateProvider { DateProvider { self.now } }
}

enum TicketsFixtures {
    static let start = Date(timeIntervalSince1970: 1_791_201_600)

    static let event = TicketedEvent(eventID: "event-1", title: "Jazz Night", venueName: "Harbor Amphitheater",
                                     start: start.addingTimeInterval(3 * 86_400), end: start.addingTimeInterval(3 * 86_400 + 7200))

    static let offers = [
        TicketOffer(id: "ga", eventID: "event-1", tier: .general, price: .usd(18), remaining: 50, maxPerOrder: 8),
        TicketOffer(id: "res", eventID: "event-1", tier: .reserved, price: .usd(36), remaining: 3, maxPerOrder: 6),
        TicketOffer(id: "vip", eventID: "event-1", tier: .vip, price: .usd(75), remaining: 0, maxPerOrder: 4),
        TicketOffer(id: "other", eventID: "event-2", tier: .general, price: .usd(5), remaining: 10, maxPerOrder: 10),
    ]

    static func repository(tickets: [CityTicket] = []) -> InMemoryTicketsRepository {
        InMemoryTicketsRepository(snapshot: TicketsSnapshot(offers: offers, holds: [], tickets: tickets))
    }

    static func payment(amount: Money) -> TicketPayment {
        TicketPayment(transactionID: "tx-1", amount: amount)
    }

    static func receipt(amount: Money, id: String = "tx-1") -> PaymentReceipt {
        PaymentReceipt(transactionID: id, merchant: "Harbor Amphitheater", amount: amount, date: start,
                       paymentMethod: PaymentMethod(id: "pm", kind: .debitCard, label: "Debit", last4: "1111", isDefault: true),
                       payerName: "Sam Lee", remainingBalance: .zero)
    }

    struct Dependencies {
        let clock = TestClock()
        let notifications = RecordingNotificationsService()
        let agenda = RecordingAgendaService()
    }

    static func service(_ repository: InMemoryTicketsRepository, _ dependencies: Dependencies = Dependencies()) -> LiveTicketsService {
        let counter = Counter()
        return LiveTicketsService(repository: repository, identity: StubIdentityService(), notifications: dependencies.notifications,
                                  agenda: dependencies.agenda, dates: dependencies.clock.provider, makeID: { counter.next() })
    }
}

final class Counter: @unchecked Sendable {
    private var value = 0
    func next() -> String {
        value += 1
        return "\(value)"
    }
}

struct StubIdentityService: IdentityService {
    func currentUser() async throws -> UserProfile {
        UserProfile(id: "user-1", fullName: "Sam Lee", email: "sam@example.com", phone: "5550199", residentID: "CIV-1",
                    address: Address(street: "1 Main", district: "Center", postalCode: "10000"), memberSince: TicketsFixtures.start)
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
        return CityNotification(id: "n", recipientID: "user-1", title: draft.title, body: draft.body, date: TicketsFixtures.start, category: draft.category, sourceDomain: draft.sourceDomain, isRead: false)
    }

    func preferences() async throws -> NotificationPreferences { NotificationPreferences() }
    func update(preferences: NotificationPreferences) async throws {}
    func summary() async -> DomainSummary { DomainSummary(title: "Inbox", detail: "") }
}

actor RecordingAgendaService: AgendaService {
    private(set) var added: [CalendarDraft] = []

    func entries(in interval: DateInterval) async throws -> [CalendarEntry] { [] }
    func upcoming(limit: Int) async throws -> [CalendarEntry] { [] }

    func add(_ draft: CalendarDraft) async throws -> CalendarEntry {
        added.append(draft)
        return CalendarEntry(id: "c", ownerID: "user-1", title: draft.title, start: draft.start, end: draft.end, location: draft.location,
                             sourceDomain: draft.sourceDomain, sourceItemID: draft.sourceItemID, reminder: draft.reminder)
    }

    func entry(sourceDomain: String, sourceItemID: String) async throws -> CalendarEntry? { nil }
    func remove(id: String) async throws {}
    func summary() async -> DomainSummary { DomainSummary(title: "Agenda", detail: "") }
}
