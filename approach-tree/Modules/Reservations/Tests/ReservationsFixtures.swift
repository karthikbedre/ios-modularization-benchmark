import Agenda
import CoreKit
import CoreModels
import Foundation
import Identity
import Notifications
@testable import Reservations
import Reservations

enum ReservationsFixtures {
    /// Monday 2026-10-05 12:00 UTC.
    static let now = Date(timeIntervalSince1970: 1_791_201_600)

    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Hour `hour` UTC on the day `daysFromNow` after `now`.
    static func at(hour: Int, minute: Int = 0, daysFromNow: Int = 0) -> Date {
        utc.date(byAdding: DateComponents(day: daysFromNow, hour: hour, minute: minute), to: utc.startOfDay(for: now))!
    }

    static let bistro = VenueSchedule(venueID: "bistro", venueName: "Bistro", kind: .dining, openHour: 17, closeHour: 21,
                                      slotMinutes: 60, durationMinutes: 60, capacity: 2, maxPartySize: 6)
    static let court = VenueSchedule(venueID: "court", venueName: "Court", kind: .facility, openHour: 9, closeHour: 12,
                                     slotMinutes: 60, durationMinutes: 60, capacity: 1, maxPartySize: 4)

    static func reservation(_ id: String, venue: VenueSchedule, start: Date, owner: String = "user-1", status: Reservation.Status = .confirmed) -> Reservation {
        Reservation(id: id, ownerID: owner, venueID: venue.venueID, venueName: venue.venueName, kind: venue.kind, start: start,
                    end: start.addingTimeInterval(TimeInterval(venue.durationMinutes * 60)), partySize: 2, notes: "", status: status, confirmationCode: "X")
    }

    static func repository(_ reservations: [Reservation] = []) -> InMemoryReservationsRepository {
        InMemoryReservationsRepository(snapshot: ReservationsSnapshot(schedules: [bistro, court], reservations: reservations))
    }

    static func service(_ repository: InMemoryReservationsRepository, notifications: RecordingNotificationsService = RecordingNotificationsService(), agenda: RecordingAgendaService = RecordingAgendaService()) -> LiveReservationsService {
        LiveReservationsService(repository: repository, identity: StubIdentityService(), notifications: notifications, agenda: agenda,
                                dates: .fixed(now), calendar: utc, makeID: { "abc123" })
    }

    static func request(_ venue: VenueSchedule, start: Date, partySize: Int = 2) -> ReservationRequest {
        ReservationRequest(venue: BookableVenue(id: venue.venueID, name: venue.venueName, kind: venue.kind), start: start, partySize: partySize, notes: "  Birthday ")
    }
}

struct StubIdentityService: IdentityService {
    func currentUser() async throws -> UserProfile {
        UserProfile(id: "user-1", fullName: "Sam Lee", email: "sam@example.com", phone: "5550199", residentID: "CIV-1",
                    address: Address(street: "1 Main", district: "Center", postalCode: "10000"), memberSince: ReservationsFixtures.now)
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
        return CityNotification(id: "n", recipientID: "user-1", title: draft.title, body: draft.body, date: ReservationsFixtures.now, category: draft.category, sourceDomain: draft.sourceDomain, isRead: false)
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
