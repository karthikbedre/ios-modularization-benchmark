import AgendaAPI
import CoreKit
import CoreModels
import Foundation
import IdentityAPI
import NotificationsAPI
import ReservationsAPI

public struct LiveReservationsService: ReservationsService {
    private let repository: any ReservationsRepository
    private let identity: any IdentityService
    private let notifications: any NotificationsService
    private let agenda: any AgendaService
    private let dates: DateProvider
    private let calendar: Calendar
    private let makeID: @Sendable () -> String

    init(
        repository: any ReservationsRepository,
        identity: any IdentityService,
        notifications: any NotificationsService,
        agenda: any AgendaService,
        dates: DateProvider = .live,
        calendar: Calendar = .current,
        makeID: @escaping @Sendable () -> String = { UUID().uuidString.prefix(8).lowercased() }
    ) {
        self.repository = repository
        self.identity = identity
        self.notifications = notifications
        self.agenda = agenda
        self.dates = dates
        self.calendar = calendar
        self.makeID = makeID
    }

    public func upcoming() async throws -> [Reservation] {
        let now = dates.now
        return try await own().filter { $0.status == .confirmed && $0.end > now }.sorted { $0.start < $1.start }
    }

    public func history() async throws -> [Reservation] {
        let now = dates.now
        return try await own().filter { $0.status == .cancelled || $0.end <= now }.sorted { $0.start > $1.start }
    }

    public func maxPartySize(venueID: String) async throws -> Int {
        try schedule(venueID, in: try await repository.load()).maxPartySize
    }

    public func availableSlots(venueID: String, on day: Date, partySize: Int) async throws -> [TimeSlot] {
        let snapshot = try await repository.load()
        let schedule = try schedule(venueID, in: snapshot)
        guard (1...schedule.maxPartySize).contains(partySize) else {
            throw ReservationsError.partySizeOutOfRange(max: schedule.maxPartySize)
        }
        return SlotPlanner.slots(for: schedule, on: day, booked: snapshot.reservations, now: dates.now, calendar: calendar)
    }

    public func book(_ request: ReservationRequest) async throws -> Reservation {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let calendar = calendar
        let id = "res-\(makeID())"

        let reservation = try await repository.update { snapshot in
            let schedule = try Self.schedule(request.venue.id, in: snapshot)
            guard (1...schedule.maxPartySize).contains(request.partySize) else {
                throw ReservationsError.partySizeOutOfRange(max: schedule.maxPartySize)
            }
            guard request.start > now else { throw ReservationsError.slotInPast }
            let slots = SlotPlanner.slots(for: schedule, on: request.start, booked: snapshot.reservations, now: now, calendar: calendar)
            guard let slot = slots.first(where: { $0.start == request.start }), !slot.isFull else {
                throw ReservationsError.slotUnavailable
            }
            let overlapsOwnBooking = snapshot.reservations.contains {
                $0.ownerID == ownerID && $0.status == .confirmed && $0.start < slot.end && $0.end > slot.start
            }
            guard !overlapsOwnBooking else { throw ReservationsError.alreadyBooked }

            let reservation = Reservation(
                id: id, ownerID: ownerID, venueID: schedule.venueID, venueName: schedule.venueName, kind: schedule.kind,
                start: slot.start, end: slot.end, partySize: request.partySize,
                notes: request.notes.trimmingCharacters(in: .whitespacesAndNewlines), status: .confirmed,
                confirmationCode: SlotPlanner.confirmationCode(venueName: schedule.venueName, seed: id)
            )
            snapshot.reservations.append(reservation)
            return reservation
        }

        // The booking already exists, so agenda and inbox failures must not fail it.
        _ = try? await agenda.add(CalendarDraft(
            title: reservation.venueName, start: reservation.start, end: reservation.end, location: reservation.venueName,
            sourceDomain: "Reservations", sourceItemID: reservation.id, reminder: .oneHour
        ))
        _ = try? await notifications.post(NotificationDraft(
            title: "\(reservation.kind == .dining ? "Table" : "Booking") confirmed",
            body: "\(reservation.venueName), \(reservation.start.formatted(date: .abbreviated, time: .shortened)), party of \(reservation.partySize). Code \(reservation.confirmationCode).",
            category: .booking,
            sourceDomain: "Reservations"
        ))
        return reservation
    }

    public func cancel(id: String) async throws {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let cancelled = try await repository.update { snapshot in
            guard let index = snapshot.reservations.firstIndex(where: { $0.id == id && $0.ownerID == ownerID && $0.status == .confirmed }) else {
                throw ReservationsError.reservationNotFound
            }
            guard snapshot.reservations[index].start > now else { throw ReservationsError.alreadyStarted }
            snapshot.reservations[index].status = .cancelled
            return snapshot.reservations[index]
        }
        _ = try? await notifications.post(NotificationDraft(
            title: "Reservation cancelled",
            body: "\(cancelled.venueName), \(cancelled.start.formatted(date: .abbreviated, time: .shortened)).",
            category: .booking,
            sourceDomain: "Reservations"
        ))
    }

    public func summary() async -> DomainSummary {
        guard let upcoming = try? await upcoming() else {
            return DomainSummary(title: "Reservations", detail: "Unavailable")
        }
        guard let next = upcoming.first else {
            return DomainSummary(title: "Reservations", detail: "Nothing booked")
        }
        return DomainSummary(title: "Reservations", detail: "\(next.venueName), \(next.start.formatted(.dateTime.weekday().hour().minute()))")
    }

    private func own() async throws -> [Reservation] {
        let ownerID = try await identity.currentUser().id
        return try await repository.load().reservations.filter { $0.ownerID == ownerID }
    }

    private func schedule(_ venueID: String, in snapshot: ReservationsSnapshot) throws(ReservationsError) -> VenueSchedule {
        try Self.schedule(venueID, in: snapshot)
    }

    private static func schedule(_ venueID: String, in snapshot: ReservationsSnapshot) throws(ReservationsError) -> VenueSchedule {
        guard let schedule = snapshot.schedules.first(where: { $0.venueID == venueID }) else { throw .venueNotFound }
        return schedule
    }
}
