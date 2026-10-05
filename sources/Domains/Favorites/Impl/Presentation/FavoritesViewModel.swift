import CoreKit
import FavoritesAPI
import Observation

@MainActor
@Observable
final class FavoritesViewModel {
    private(set) var state: LoadState<[FavoriteItem]> = .idle
    var kind: FavoriteKind?

    private let service: any FavoritesService

    init(service: any FavoritesService) {
        self.service = service
    }

    /// Kinds that have at least one item, in a stable order, for section headers.
    var groups: [(kind: FavoriteKind, items: [FavoriteItem])] {
        let items = state.value ?? []
        return FavoriteKind.allCases.compactMap { kind in
            let matching = items.filter { $0.kind == kind }
            return matching.isEmpty ? nil : (kind, matching)
        }
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await service.favorites(of: kind))
        } catch {
            state = .failed("Saved items could not be loaded.")
        }
    }

    func remove(_ item: FavoriteItem) async {
        try? await service.remove(id: item.id)
        await load()
    }
}
