import Agenda
import CoreKit
import CoreModels
import Foundation
import Identity
import Notifications

public struct LiveTicketsService: TicketsService {
    static let holdDuration: TimeInterval = 10 * 60
    static let cancellationCutoff: TimeInterval = 24 * 3600

    private let repository: any TicketsRepository
    private let identity: any IdentityService
    private let notifications: any NotificationsService
    private let agenda: any AgendaService
    private let dates: DateProvider
    private let makeID: @Sendable () -> String

    init(
        repository: any TicketsRepository,
        identity: any IdentityService,
        notifications: any NotificationsService,
        agenda: any AgendaService,
        dates: DateProvider = .live,
        makeID: @escaping @Sendable () -> String = { UUID().uuidString.prefix(8).lowercased() }
    ) {
        self.repository = repository
        self.identity = identity
        self.notifications = notifications
        self.agenda = agenda
        self.dates = dates
        self.makeID = makeID
    }

    public func offers(eventID: String) async throws -> [TicketOffer] {
        let now = dates.now
        return try await repository.update { snapshot in
            Self.releaseExpiredHolds(in: &snapshot, now: now)
            return snapshot.offers.filter { $0.eventID == eventID }.sorted { $0.price < $1.price }
        }
    }

    public func myTickets() async throws -> [CityTicket] {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let tickets = try await repository.load().tickets.filter { $0.ownerID == ownerID }
        let upcoming = tickets.filter { $0.status == .active && $0.event.end > now }.sorted { $0.event.start < $1.event.start }
        let past = tickets.filter { !upcoming.contains($0) }.sorted { $0.event.start > $1.event.start }
        return upcoming + past
    }

    public func hold(offerID: String, quantity: Int, for event: TicketedEvent) async throws -> TicketHold {
        let now = dates.now
        let id = "hold-\(makeID())"
        return try await repository.update { snapshot in
            Self.releaseExpiredHolds(in: &snapshot, now: now)
            guard let index = snapshot.offers.firstIndex(where: { $0.id == offerID && $0.eventID == event.eventID }) else {
                throw TicketsError.offerNotFound
            }
            let offer = snapshot.offers[index]
            guard !offer.isSoldOut else { throw TicketsError.soldOut }
            let max = min(offer.maxPerOrder, offer.remaining)
            guard (1...max).contains(quantity) else { throw TicketsError.quantityOutOfRange(max: max) }

            snapshot.offers[index].remaining -= quantity
            let hold = TicketHold(id: id, offerID: offer.id, event: event, tier: offer.tier, quantity: quantity,
                                  total: offer.price * quantity, expiresAt: now.addingTimeInterval(Self.holdDuration))
            snapshot.holds.append(hold)
            return hold
        }
    }

    public func release(holdID: String) async throws {
        try await repository.update { snapshot in
            guard let hold = snapshot.holds.first(where: { $0.id == holdID }) else { throw TicketsError.holdNotFound }
            Self.release(hold, in: &snapshot)
        }
    }

    public func confirm(holdID: String, payment: TicketPayment) async throws -> [CityTicket] {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let makeID = makeID

        let tickets = try await repository.update { snapshot in
            guard let hold = snapshot.holds.first(where: { $0.id == holdID }) else { throw TicketsError.holdNotFound }
            guard hold.expiresAt > now else {
                Self.release(hold, in: &snapshot)
                throw TicketsError.holdExpired
            }
            guard payment.amount == hold.total else { throw TicketsError.paymentMismatch }

            let alreadySold = snapshot.tickets.count { $0.event.eventID == hold.event.eventID && $0.tier == hold.tier }
            let issued = (0..<hold.quantity).map { offset in
                CityTicket(
                    id: "ticket-\(makeID())", ownerID: ownerID, event: hold.event, tier: hold.tier,
                    seat: SeatAssigner.seat(for: hold.tier, number: alreadySold + offset),
                    price: Money(minorUnits: hold.total.minorUnits / hold.quantity, currencyCode: hold.total.currencyCode),
                    status: .active, purchasedAt: now, transactionID: payment.transactionID
                )
            }
            snapshot.tickets.append(contentsOf: issued)
            snapshot.holds.removeAll { $0.id == holdID }
            return issued
        }

        if let first = tickets.first {
            await announce(first.event, count: tickets.count)
        }
        return tickets
    }

    public func cancel(ticketID: String) async throws {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        try await repository.update { snapshot in
            guard let index = snapshot.tickets.firstIndex(where: { $0.id == ticketID && $0.ownerID == ownerID && $0.status == .active }) else {
                throw TicketsError.ticketNotFound
            }
            let ticket = snapshot.tickets[index]
            guard ticket.event.start.timeIntervalSince(now) > Self.cancellationCutoff else { throw TicketsError.tooLateToCancel }
            snapshot.tickets[index].status = .cancelled
            if let offer = snapshot.offers.firstIndex(where: { $0.eventID == ticket.event.eventID && $0.tier == ticket.tier }) {
                snapshot.offers[offer].remaining += 1
            }
        }
    }

    public func summary() async -> DomainSummary {
        guard let tickets = try? await myTickets() else {
            return DomainSummary(title: "Tickets", detail: "Unavailable")
        }
        let upcoming = tickets.filter { $0.status == .active && $0.event.end > dates.now }
        guard let next = upcoming.first else {
            return DomainSummary(title: "Tickets", detail: "No upcoming tickets")
        }
        return DomainSummary(title: "Tickets", detail: "\(upcoming.count) upcoming · next \(next.event.title)")
    }

    private static func releaseExpiredHolds(in snapshot: inout TicketsSnapshot, now: Date) {
        for hold in snapshot.holds where hold.expiresAt <= now {
            release(hold, in: &snapshot)
        }
    }

    private static func release(_ hold: TicketHold, in snapshot: inout TicketsSnapshot) {
        if let index = snapshot.offers.firstIndex(where: { $0.id == hold.offerID }) {
            snapshot.offers[index].remaining += hold.quantity
        }
        snapshot.holds.removeAll { $0.id == hold.id }
    }

    /// The tickets are issued at this point, so agenda and inbox failures must not fail the purchase.
    private func announce(_ event: TicketedEvent, count: Int) async {
        _ = try? await agenda.add(CalendarDraft(
            title: event.title, start: event.start, end: event.end, location: event.venueName,
            sourceDomain: "Tickets", sourceItemID: event.eventID, reminder: .oneDay
        ))
        _ = try? await notifications.post(NotificationDraft(
            title: count == 1 ? "Your ticket is ready" : "Your \(count) tickets are ready",
            body: "\(event.title) at \(event.venueName), \(event.start.formatted(date: .abbreviated, time: .shortened)).",
            category: .booking,
            sourceDomain: "Tickets"
        ))
    }
}

enum SeatAssigner {
    /// General admission has no seats. Reserved and VIP fill rows of 20 in order of sale.
    static func seat(for tier: TicketTier, number: Int) -> String? {
        let rows = Array("ABCDEFGHJKLMNPQRSTUV")
        switch tier {
        case .general:
            return nil
        case .reserved, .vip:
            let rowOffset = tier == .vip ? 0 : 3
            let row = rows[(rowOffset + number / 20) % rows.count]
            return "Row \(row), seat \(number % 20 + 1)"
        }
    }
}
