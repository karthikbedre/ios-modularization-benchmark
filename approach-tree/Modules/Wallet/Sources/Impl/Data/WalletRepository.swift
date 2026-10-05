import CoreKit
import CoreModels
import Foundation

struct WalletSnapshot: Hashable, Sendable, Codable {
    var balance: Money
    var paymentMethods: [PaymentMethod]
    var transactions: [WalletTransaction]
}

protocol WalletRepository: Sendable {
    func load() async throws -> WalletSnapshot
    /// Applies `change` atomically, so concurrent payments cannot overdraw the balance.
    func update<Result: Sendable>(_ change: @Sendable (inout WalletSnapshot) throws -> Result) async throws -> Result
}

/// Serves the bundled fixture and keeps payments in memory for the session.
actor BundleWalletRepository: WalletRepository {
    private let loader: MockDataLoader
    private var cached: WalletSnapshot?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func load() async throws -> WalletSnapshot {
        if let cached { return cached }
        let snapshot = try await loader.load(WalletSnapshot.self, resource: "wallet", in: .module)
        // Another call may have loaded and changed the snapshot while this one awaited.
        if let cached { return cached }
        cached = snapshot
        return snapshot
    }

    func update<Result: Sendable>(_ change: @Sendable (inout WalletSnapshot) throws -> Result) async throws -> Result {
        var snapshot = try await load()
        let result = try change(&snapshot)
        cached = snapshot
        return result
    }
}

actor InMemoryWalletRepository: WalletRepository {
    private(set) var snapshot: WalletSnapshot

    init(snapshot: WalletSnapshot) {
        self.snapshot = snapshot
    }

    func load() async throws -> WalletSnapshot { snapshot }

    func update<Result: Sendable>(_ change: @Sendable (inout WalletSnapshot) throws -> Result) async throws -> Result {
        try change(&snapshot)
    }
}
