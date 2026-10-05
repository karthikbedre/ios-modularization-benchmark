import CoreKit
import Foundation

struct DiningCatalog: Hashable, Sendable, Codable {
    var restaurants: [Restaurant]
    var menus: [String: [MenuSection]]
}

protocol DiningRepository: Sendable {
    func catalog() async throws -> DiningCatalog
}

actor BundleDiningRepository: DiningRepository {
    private let loader: MockDataLoader
    private var cached: DiningCatalog?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func catalog() async throws -> DiningCatalog {
        if let cached { return cached }
        let catalog = try await loader.load(DiningCatalog.self, resource: "dining", in: .module)
        cached = catalog
        return catalog
    }
}

struct InMemoryDiningRepository: DiningRepository {
    var stored: DiningCatalog

    func catalog() async throws -> DiningCatalog { stored }
}
