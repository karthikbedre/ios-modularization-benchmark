#if DEBUG
import CoreModels
import Foundation

public struct PreviewFavoritesService: FavoritesService {
    public init() {}

    public func favorites(of kind: FavoriteKind?) async throws -> [FavoriteItem] {
        [FavoriteItem(id: "f1", ownerID: "user-preview", kind: .restaurant, itemID: "r1", title: "Noodle Bar 88", subtitle: "Old Town", addedAt: .now)]
    }

    public func isFavorite(kind: FavoriteKind, itemID: String) async throws -> Bool { false }
    public func toggle(_ draft: FavoriteDraft) async throws -> Bool { true }
    public func remove(id: String) async throws {}

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Saved", detail: "1 saved item")
    }
}
#endif
