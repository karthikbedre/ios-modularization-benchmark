#if DEBUG
import CoreModels
import Foundation

extension Reservation {
    public static let preview = Reservation(
        id: "r1", ownerID: "user-preview", venueID: "rest-noodle-88", venueName: "Noodle Bar 88", kind: .dining,
        start: .now.addingTimeInterval(86_400), end: .now.addingTimeInterval(86_400 + 5400), partySize: 2, notes: "",
        status: .confirmed, confirmationCode: "NB8-2Q4"
    )
}

public struct PreviewReservationsService: ReservationsService {
    public init() {}

    public func upcoming() async throws -> [Reservation] { [.preview] }
    public func history() async throws -> [Reservation] { [] }
    public func maxPartySize(venueID: String) async throws -> Int { 8 }

    public func availableSlots(venueID: String, on day: Date, partySize: Int) async throws -> [TimeSlot] {
        let start = Calendar.current.startOfDay(for: day).addingTimeInterval(18 * 3600)
        return (0..<6).map { TimeSlot(start: start.addingTimeInterval(Double($0) * 1800), end: start.addingTimeInterval(Double($0) * 1800 + 5400), remaining: $0 == 2 ? 0 : 3) }
    }

    public func book(_ request: ReservationRequest) async throws -> Reservation { .preview }
    public func cancel(id: String) async throws {}

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Reservations", detail: "Noodle Bar 88 tomorrow")
    }
}
#endif
