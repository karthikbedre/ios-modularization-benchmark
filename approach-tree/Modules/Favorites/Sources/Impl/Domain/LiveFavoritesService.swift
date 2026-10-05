import CoreKit
import CoreModels
import Foundation
import Identity

public struct LiveFavoritesService: FavoritesService {
    static let limit = 100

    private let repository: any FavoritesRepository
    private let identity: any IdentityService
    private let dates: DateProvider
    private let makeID: @Sendable () -> String

    init(
        repository: any FavoritesRepository,
        identity: any IdentityService,
        dates: DateProvider = .live,
        makeID: @escaping @Sendable () -> String = { "fav-\(UUID().uuidString.prefix(8))" }
    ) {
        self.repository = repository
        self.identity = identity
        self.dates = dates
        self.makeID = makeID
    }

    public func favorites(of kind: FavoriteKind?) async throws -> [FavoriteItem] {
        let ownerID = try await identity.currentUser().id
        return try await repository.load()
            .filter { $0.ownerID == ownerID && (kind == nil || $0.kind == kind) }
            .sorted { $0.addedAt > $1.addedAt }
    }

    public func isFavorite(kind: FavoriteKind, itemID: String) async throws -> Bool {
        try await favorites(of: kind).contains { $0.itemID == itemID }
    }

    @discardableResult
    public func toggle(_ draft: FavoriteDraft) async throws -> Bool {
        let ownerID = try await identity.currentUser().id
        let id = makeID()
        let now = dates.now
        let limit = Self.limit

        return try await repository.update { items in
            if let index = items.firstIndex(where: { $0.ownerID == ownerID && $0.kind == draft.kind && $0.itemID == draft.itemID }) {
                items.remove(at: index)
                return false
            }
            guard items.count(where: { $0.ownerID == ownerID }) < limit else {
                throw FavoritesError.limitReached(limit)
            }
            items.append(FavoriteItem(id: id, ownerID: ownerID, kind: draft.kind, itemID: draft.itemID, title: draft.title, subtitle: draft.subtitle, addedAt: now))
            return true
        }
    }

    public func remove(id: String) async throws {
        let ownerID = try await identity.currentUser().id
        try await repository.update { items in
            guard items.contains(where: { $0.id == id && $0.ownerID == ownerID }) else {
                throw FavoritesError.notFound
            }
            items.removeAll { $0.id == id }
        }
    }

    public func summary() async -> DomainSummary {
        guard let items = try? await favorites(of: nil) else {
            return DomainSummary(title: "Saved", detail: "Unavailable")
        }
        return DomainSummary(title: "Saved", detail: items.isEmpty ? "Nothing saved yet" : "\(items.count) saved items")
    }
}
