import CoreKit
import Foundation
import LibraryAPI

struct LibrarySnapshot: Hashable, Sendable, Codable {
    var books: [Book]
    var loans: [Loan]
    var holds: [Hold]
}

protocol LibraryRepository: Sendable {
    func load() async throws -> LibrarySnapshot
    func update<Result: Sendable>(_ change: @Sendable (inout LibrarySnapshot) throws -> Result) async throws -> Result
}

actor BundleLibraryRepository: LibraryRepository {
    private let loader: MockDataLoader
    private var cached: LibrarySnapshot?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func load() async throws -> LibrarySnapshot {
        if let cached { return cached }
        let snapshot = try await loader.load(LibrarySnapshot.self, resource: "library", in: .module)
        if let cached { return cached }
        cached = snapshot
        return snapshot
    }

    func update<Result: Sendable>(_ change: @Sendable (inout LibrarySnapshot) throws -> Result) async throws -> Result {
        var snapshot = try await load()
        let result = try change(&snapshot)
        cached = snapshot
        return result
    }
}

actor InMemoryLibraryRepository: LibraryRepository {
    private(set) var snapshot: LibrarySnapshot

    init(snapshot: LibrarySnapshot) {
        self.snapshot = snapshot
    }

    func load() async throws -> LibrarySnapshot { snapshot }

    func update<Result: Sendable>(_ change: @Sendable (inout LibrarySnapshot) throws -> Result) async throws -> Result {
        try change(&snapshot)
    }
}
