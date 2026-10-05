import CoreKit
import Foundation
import NotificationsAPI

struct NotificationsSnapshot: Hashable, Sendable, Codable {
    var notifications: [CityNotification]
    var preferences: NotificationPreferences
}

protocol NotificationsRepository: Sendable {
    func load() async throws -> NotificationsSnapshot
    func update<Result: Sendable>(_ change: @Sendable (inout NotificationsSnapshot) throws -> Result) async throws -> Result
}

actor BundleNotificationsRepository: NotificationsRepository {
    private let loader: MockDataLoader
    private var cached: NotificationsSnapshot?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func load() async throws -> NotificationsSnapshot {
        if let cached { return cached }
        let snapshot = try await loader.load(NotificationsSnapshot.self, resource: "notifications", in: .module)
        if let cached { return cached }
        cached = snapshot
        return snapshot
    }

    func update<Result: Sendable>(_ change: @Sendable (inout NotificationsSnapshot) throws -> Result) async throws -> Result {
        var snapshot = try await load()
        let result = try change(&snapshot)
        cached = snapshot
        return result
    }
}

actor InMemoryNotificationsRepository: NotificationsRepository {
    private(set) var snapshot: NotificationsSnapshot

    init(snapshot: NotificationsSnapshot) {
        self.snapshot = snapshot
    }

    func load() async throws -> NotificationsSnapshot { snapshot }

    func update<Result: Sendable>(_ change: @Sendable (inout NotificationsSnapshot) throws -> Result) async throws -> Result {
        try change(&snapshot)
    }
}
