import CoreModels
import Foundation
import SwiftUI

public protocol ReservationsService: SummaryProviding {
    func upcoming() async throws -> [Reservation]
    func history() async throws -> [Reservation]
    func maxPartySize(venueID: String) async throws -> Int
    /// Bookable slots on the calendar day containing `day`, with capacity left for `partySize`.
    func availableSlots(venueID: String, on day: Date, partySize: Int) async throws -> [TimeSlot]
    /// Books the slot, adds it to the agenda and confirms in the inbox.
    func book(_ request: ReservationRequest) async throws -> Reservation
    func cancel(id: String) async throws
}

public struct ReservationsEntryPoints: Sendable {
    public var booking: @MainActor @Sendable (BookableVenue) -> AnyView
    public var myReservations: @MainActor @Sendable () -> AnyView

    public init(booking: @escaping @MainActor @Sendable (BookableVenue) -> AnyView, myReservations: @escaping @MainActor @Sendable () -> AnyView) {
        self.booking = booking
        self.myReservations = myReservations
    }
}
