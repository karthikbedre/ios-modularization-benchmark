import CoreKit
import Foundation
import ReservationsAPI

struct VenueSchedule: Hashable, Sendable, Codable {
    var venueID: String
    var venueName: String
    var kind: ReservationKind
    var openHour: Int
    var closeHour: Int
    var slotMinutes: Int
    var durationMinutes: Int
    /// Bookings that fit into one slot, such as tables or courts.
    var capacity: Int
    var maxPartySize: Int
}

struct ReservationsSnapshot: Hashable, Sendable, Codable {
    var schedules: [VenueSchedule]
    var reservations: [Reservation]
}

protocol ReservationsRepository: Sendable {
    func load() async throws -> ReservationsSnapshot
    func update<Result: Sendable>(_ change: @Sendable (inout ReservationsSnapshot) throws -> Result) async throws -> Result
}

actor BundleReservationsRepository: ReservationsRepository {
    private let loader: MockDataLoader
    private var cached: ReservationsSnapshot?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func load() async throws -> ReservationsSnapshot {
        if let cached { return cached }
        let snapshot = try await loader.load(ReservationsSnapshot.self, resource: "reservations", in: .module)
        if let cached { return cached }
        cached = snapshot
        return snapshot
    }

    func update<Result: Sendable>(_ change: @Sendable (inout ReservationsSnapshot) throws -> Result) async throws -> Result {
        var snapshot = try await load()
        let result = try change(&snapshot)
        cached = snapshot
        return result
    }
}

actor InMemoryReservationsRepository: ReservationsRepository {
    private(set) var snapshot: ReservationsSnapshot

    init(snapshot: ReservationsSnapshot) {
        self.snapshot = snapshot
    }

    func load() async throws -> ReservationsSnapshot { snapshot }

    func update<Result: Sendable>(_ change: @Sendable (inout ReservationsSnapshot) throws -> Result) async throws -> Result {
        try change(&snapshot)
    }
}
