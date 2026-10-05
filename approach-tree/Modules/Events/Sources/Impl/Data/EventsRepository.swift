import CoreKit
import Foundation

protocol EventsRepository: Sendable {
    func events() async throws -> [CityEvent]
}

/// The event listing is published by the city, so the app only reads it.
actor BundleEventsRepository: EventsRepository {
    private let loader: MockDataLoader
    private var cached: [CityEvent]?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func events() async throws -> [CityEvent] {
        if let cached { return cached }
        let events = try await loader.load([CityEvent].self, resource: "events", in: .module)
        cached = events
        return events
    }
}

struct InMemoryEventsRepository: EventsRepository {
    var stored: [CityEvent]

    func events() async throws -> [CityEvent] { stored }
}
