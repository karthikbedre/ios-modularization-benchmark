import CoreModels
import SwiftUI

public protocol TicketsService: SummaryProviding {
    func offers(eventID: String) async throws -> [TicketOffer]
    func myTickets() async throws -> [CityTicket]
    func hold(offerID: String, quantity: Int, for event: TicketedEvent) async throws -> TicketHold
    /// Releases the seats of a hold that will not be paid for.
    func release(holdID: String) async throws
    /// Issues tickets for a paid hold, adds the event to the agenda and confirms in the inbox.
    func confirm(holdID: String, payment: TicketPayment) async throws -> [CityTicket]
    func cancel(ticketID: String) async throws
}

public struct TicketsEntryPoints: Sendable {
    public var purchase: @MainActor @Sendable (TicketedEvent) -> AnyView
    public var myTickets: @MainActor @Sendable () -> AnyView

    public init(purchase: @escaping @MainActor @Sendable (TicketedEvent) -> AnyView, myTickets: @escaping @MainActor @Sendable () -> AnyView) {
        self.purchase = purchase
        self.myTickets = myTickets
    }
}
