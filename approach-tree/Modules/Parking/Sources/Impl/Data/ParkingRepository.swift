import CoreKit
import Foundation

struct ParkingSnapshot: Hashable, Sendable, Codable {
    var zones: [ParkingZone]
    var vehicles: [Vehicle]
    var sessions: [ParkingSession]
}

protocol ParkingRepository: Sendable {
    func load() async throws -> ParkingSnapshot
    func update<Result: Sendable>(_ change: @Sendable (inout ParkingSnapshot) throws -> Result) async throws -> Result
}

actor BundleParkingRepository: ParkingRepository {
    private let loader: MockDataLoader
    private var cached: ParkingSnapshot?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func load() async throws -> ParkingSnapshot {
        if let cached { return cached }
        let snapshot = try await loader.load(ParkingSnapshot.self, resource: "parking", in: .module)
        if let cached { return cached }
        cached = snapshot
        return snapshot
    }

    func update<Result: Sendable>(_ change: @Sendable (inout ParkingSnapshot) throws -> Result) async throws -> Result {
        var snapshot = try await load()
        let result = try change(&snapshot)
        cached = snapshot
        return result
    }
}

actor InMemoryParkingRepository: ParkingRepository {
    private(set) var snapshot: ParkingSnapshot

    init(snapshot: ParkingSnapshot) {
        self.snapshot = snapshot
    }

    func load() async throws -> ParkingSnapshot { snapshot }

    func update<Result: Sendable>(_ change: @Sendable (inout ParkingSnapshot) throws -> Result) async throws -> Result {
        try change(&snapshot)
    }
}
