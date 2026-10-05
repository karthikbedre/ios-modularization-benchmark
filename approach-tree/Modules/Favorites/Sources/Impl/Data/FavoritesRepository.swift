import CoreKit
import Foundation

protocol FavoritesRepository: Sendable {
    func load() async throws -> [FavoriteItem]
    func update<Result: Sendable>(_ change: @Sendable (inout [FavoriteItem]) throws -> Result) async throws -> Result
}

actor BundleFavoritesRepository: FavoritesRepository {
    private let loader: MockDataLoader
    private var cached: [FavoriteItem]?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func load() async throws -> [FavoriteItem] {
        if let cached { return cached }
        let items = try await loader.load([FavoriteItem].self, resource: "favorites", in: .module)
        if let cached { return cached }
        cached = items
        return items
    }

    func update<Result: Sendable>(_ change: @Sendable (inout [FavoriteItem]) throws -> Result) async throws -> Result {
        var items = try await load()
        let result = try change(&items)
        cached = items
        return result
    }
}

actor InMemoryFavoritesRepository: FavoritesRepository {
    private(set) var items: [FavoriteItem]

    init(items: [FavoriteItem]) {
        self.items = items
    }

    func load() async throws -> [FavoriteItem] { items }

    func update<Result: Sendable>(_ change: @Sendable (inout [FavoriteItem]) throws -> Result) async throws -> Result {
        try change(&items)
    }
}
