import Foundation

public enum ReservationKind: String, CaseIterable, Hashable, Sendable, Codable {
    case dining, facility

    public var title: String {
        switch self {
        case .dining: "Table"
        case .facility: "Facility"
        }
    }
}

/// What a domain like Dining hands to Reservations to start a booking.
public struct BookableVenue: Hashable, Sendable {
    public var id: String
    public var name: String
    public var kind: ReservationKind

    public init(id: String, name: String, kind: ReservationKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

public struct TimeSlot: Identifiable, Hashable, Sendable {
    public var start: Date
    public var end: Date
    public var remaining: Int

    public init(start: Date, end: Date, remaining: Int) {
        self.start = start
        self.end = end
        self.remaining = remaining
    }

    public var id: Date { start }
    public var isFull: Bool { remaining == 0 }
}

public struct ReservationRequest: Hashable, Sendable {
    public var venue: BookableVenue
    public var start: Date
    public var partySize: Int
    public var notes: String

    public init(venue: BookableVenue, start: Date, partySize: Int, notes: String = "") {
        self.venue = venue
        self.start = start
        self.partySize = partySize
        self.notes = notes
    }
}

public struct Reservation: Identifiable, Hashable, Sendable, Codable {
    public enum Status: String, Hashable, Sendable, Codable {
        case confirmed, cancelled
    }

    public var id: String
    public var ownerID: String
    public var venueID: String
    public var venueName: String
    public var kind: ReservationKind
    public var start: Date
    public var end: Date
    public var partySize: Int
    public var notes: String
    public var status: Status
    /// Short code the resident shows on arrival.
    public var confirmationCode: String

    public init(id: String, ownerID: String, venueID: String, venueName: String, kind: ReservationKind, start: Date, end: Date, partySize: Int, notes: String, status: Status, confirmationCode: String) {
        self.id = id
        self.ownerID = ownerID
        self.venueID = venueID
        self.venueName = venueName
        self.kind = kind
        self.start = start
        self.end = end
        self.partySize = partySize
        self.notes = notes
        self.status = status
        self.confirmationCode = confirmationCode
    }
}

public enum ReservationsError: Error, Hashable, Sendable {
    case venueNotFound
    case partySizeOutOfRange(max: Int)
    case slotUnavailable
    case slotInPast
    case alreadyBooked
    case reservationNotFound
    case alreadyStarted
}
