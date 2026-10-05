import CoreKit
import Foundation
import TransitAPI

struct TransitSnapshot: Hashable, Sendable, Codable {
    var stops: [TransitStop]
    var lines: [TransitLine]
    var passOptions: [PassOption]
    var passes: [TransitPass]
}

protocol TransitRepository: Sendable {
    func load() async throws -> TransitSnapshot
    func update<Result: Sendable>(_ change: @Sendable (inout TransitSnapshot) throws -> Result) async throws -> Result
}

actor BundleTransitRepository: TransitRepository {
    private let loader: MockDataLoader
    private var cached: TransitSnapshot?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func load() async throws -> TransitSnapshot {
        if let cached { return cached }
        let snapshot = try await loader.load(TransitSnapshot.self, resource: "transit", in: .module)
        if let cached { return cached }
        cached = snapshot
        return snapshot
    }

    func update<Result: Sendable>(_ change: @Sendable (inout TransitSnapshot) throws -> Result) async throws -> Result {
        var snapshot = try await load()
        let result = try change(&snapshot)
        cached = snapshot
        return result
    }
}

actor InMemoryTransitRepository: TransitRepository {
    private(set) var snapshot: TransitSnapshot

    init(snapshot: TransitSnapshot) {
        self.snapshot = snapshot
    }

    func load() async throws -> TransitSnapshot { snapshot }

    func update<Result: Sendable>(_ change: @Sendable (inout TransitSnapshot) throws -> Result) async throws -> Result {
        try change(&snapshot)
    }
}
