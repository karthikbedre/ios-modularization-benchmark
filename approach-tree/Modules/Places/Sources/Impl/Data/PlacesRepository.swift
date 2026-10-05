import CoreKit
import Foundation

protocol PlacesRepository: Sendable {
    func places() async throws -> [Place]
}

/// Places are reference data, so the fixture is read once and never changes.
actor BundlePlacesRepository: PlacesRepository {
    private let loader: MockDataLoader
    private var cached: [Place]?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func places() async throws -> [Place] {
        if let cached { return cached }
        let places = try await loader.load([Place].self, resource: "places", in: .module)
        cached = places
        return places
    }
}

struct InMemoryPlacesRepository: PlacesRepository {
    var stored: [Place]

    func places() async throws -> [Place] { stored }
}
