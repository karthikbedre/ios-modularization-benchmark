import CoreKit
import Foundation
import TicketsAPI

struct TicketsSnapshot: Hashable, Sendable, Codable {
    var offers: [TicketOffer]
    var holds: [TicketHold]
    var tickets: [CityTicket]
}

protocol TicketsRepository: Sendable {
    func load() async throws -> TicketsSnapshot
    func update<Result: Sendable>(_ change: @Sendable (inout TicketsSnapshot) throws -> Result) async throws -> Result
}

actor BundleTicketsRepository: TicketsRepository {
    private let loader: MockDataLoader
    private var cached: TicketsSnapshot?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func load() async throws -> TicketsSnapshot {
        if let cached { return cached }
        let snapshot = try await loader.load(TicketsSnapshot.self, resource: "tickets", in: .module)
        if let cached { return cached }
        cached = snapshot
        return snapshot
    }

    func update<Result: Sendable>(_ change: @Sendable (inout TicketsSnapshot) throws -> Result) async throws -> Result {
        var snapshot = try await load()
        let result = try change(&snapshot)
        cached = snapshot
        return result
    }
}

actor InMemoryTicketsRepository: TicketsRepository {
    private(set) var snapshot: TicketsSnapshot

    init(snapshot: TicketsSnapshot) {
        self.snapshot = snapshot
    }

    func load() async throws -> TicketsSnapshot { snapshot }

    func update<Result: Sendable>(_ change: @Sendable (inout TicketsSnapshot) throws -> Result) async throws -> Result {
        try change(&snapshot)
    }
}
