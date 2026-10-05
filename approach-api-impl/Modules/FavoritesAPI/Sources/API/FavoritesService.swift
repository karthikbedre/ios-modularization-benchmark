import CoreModels
import SwiftUI

public protocol FavoritesService: SummaryProviding {
    /// The resident's favorites, newest first. Pass nil for every kind.
    func favorites(of kind: FavoriteKind?) async throws -> [FavoriteItem]
    func isFavorite(kind: FavoriteKind, itemID: String) async throws -> Bool
    /// Saves the item if it is not a favorite yet, otherwise removes it. Returns the new state.
    @discardableResult
    func toggle(_ draft: FavoriteDraft) async throws -> Bool
    func remove(id: String) async throws
}

public struct FavoritesEntryPoints: Sendable {
    /// A heart button that reflects and toggles the saved state of one item.
    public var toggleButton: @MainActor @Sendable (FavoriteDraft) -> AnyView
    public var list: @MainActor @Sendable () -> AnyView

    public init(
        toggleButton: @escaping @MainActor @Sendable (FavoriteDraft) -> AnyView,
        list: @escaping @MainActor @Sendable () -> AnyView
    ) {
        self.toggleButton = toggleButton
        self.list = list
    }
}
