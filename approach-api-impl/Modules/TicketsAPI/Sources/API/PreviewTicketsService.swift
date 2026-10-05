#if DEBUG
import CoreModels
import Foundation

extension TicketedEvent {
    public static let preview = TicketedEvent(
        eventID: "event-jazz", title: "Autumn Jazz Night", venueName: "Harbor Amphitheater",
        start: .now.addingTimeInterval(3 * 86_400), end: .now.addingTimeInterval(3 * 86_400 + 10_800)
    )
}

public struct PreviewTicketsService: TicketsService {
    public init() {}

    public func offers(eventID: String) async throws -> [TicketOffer] {
        [
            TicketOffer(id: "o1", eventID: eventID, tier: .general, price: .usd(18), remaining: 120, maxPerOrder: 8),
            TicketOffer(id: "o2", eventID: eventID, tier: .vip, price: .usd(65), remaining: 0, maxPerOrder: 4),
        ]
    }

    public func myTickets() async throws -> [CityTicket] {
        [CityTicket(id: "t1", ownerID: "user-preview", event: .preview, tier: .general, seat: nil, price: .usd(18), status: .active, purchasedAt: .now, transactionID: "tx")]
    }

    public func hold(offerID: String, quantity: Int, for event: TicketedEvent) async throws -> TicketHold {
        TicketHold(id: "h1", offerID: offerID, event: event, tier: .general, quantity: quantity, total: .usd(18) * quantity, expiresAt: .now.addingTimeInterval(600))
    }

    public func release(holdID: String) async throws {}
    public func confirm(holdID: String, payment: TicketPayment) async throws -> [CityTicket] { try await myTickets() }
    public func cancel(ticketID: String) async throws {}

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Tickets", detail: "1 upcoming ticket")
    }
}
#endif
