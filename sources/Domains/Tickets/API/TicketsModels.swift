import CoreModels
import Foundation

public enum TicketTier: String, CaseIterable, Hashable, Sendable, Codable {
    case general, reserved, vip

    public var title: String {
        switch self {
        case .general: "General admission"
        case .reserved: "Reserved seating"
        case .vip: "VIP"
        }
    }
}

public struct TicketOffer: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var eventID: String
    public var tier: TicketTier
    public var price: Money
    public var remaining: Int
    public var maxPerOrder: Int

    public init(id: String, eventID: String, tier: TicketTier, price: Money, remaining: Int, maxPerOrder: Int) {
        self.id = id
        self.eventID = eventID
        self.tier = tier
        self.price = price
        self.remaining = remaining
        self.maxPerOrder = maxPerOrder
    }

    public var isSoldOut: Bool { remaining == 0 }
}

/// What Events hands to Tickets, since Tickets does not know about events on its own.
public struct TicketedEvent: Hashable, Sendable, Codable {
    public var eventID: String
    public var title: String
    public var venueName: String
    public var start: Date
    public var end: Date

    public init(eventID: String, title: String, venueName: String, start: Date, end: Date) {
        self.eventID = eventID
        self.title = title
        self.venueName = venueName
        self.start = start
        self.end = end
    }
}

/// Seats set aside while the resident pays, so they cannot sell out mid-checkout.
public struct TicketHold: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var offerID: String
    public var event: TicketedEvent
    public var tier: TicketTier
    public var quantity: Int
    public var total: Money
    public var expiresAt: Date

    public init(id: String, offerID: String, event: TicketedEvent, tier: TicketTier, quantity: Int, total: Money, expiresAt: Date) {
        self.id = id
        self.offerID = offerID
        self.event = event
        self.tier = tier
        self.quantity = quantity
        self.total = total
        self.expiresAt = expiresAt
    }
}

public struct CityTicket: Identifiable, Hashable, Sendable, Codable {
    public enum Status: String, Hashable, Sendable, Codable {
        case active, used, cancelled
    }

    public var id: String
    public var ownerID: String
    public var event: TicketedEvent
    public var tier: TicketTier
    public var seat: String?
    public var price: Money
    public var status: Status
    public var purchasedAt: Date
    public var transactionID: String

    public init(id: String, ownerID: String, event: TicketedEvent, tier: TicketTier, seat: String?, price: Money, status: Status, purchasedAt: Date, transactionID: String) {
        self.id = id
        self.ownerID = ownerID
        self.event = event
        self.tier = tier
        self.seat = seat
        self.price = price
        self.status = status
        self.purchasedAt = purchasedAt
        self.transactionID = transactionID
    }
}

/// Proof of payment for a hold. Tickets only needs these two facts, so it does not depend on Wallet's types.
public struct TicketPayment: Hashable, Sendable {
    public var transactionID: String
    public var amount: Money

    public init(transactionID: String, amount: Money) {
        self.transactionID = transactionID
        self.amount = amount
    }
}

public enum TicketsError: Error, Hashable, Sendable {
    case offerNotFound
    case soldOut
    case quantityOutOfRange(max: Int)
    case holdExpired
    case holdNotFound
    case paymentMismatch
    case ticketNotFound
    case tooLateToCancel
}
