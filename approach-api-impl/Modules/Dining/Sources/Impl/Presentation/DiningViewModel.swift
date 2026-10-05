import CoreKit
import DiningAPI
import Observation

@MainActor
@Observable
final class DiningViewModel {
    private(set) var state: LoadState<[Restaurant]> = .idle
    var filter = DiningFilter()
    var searchText = ""

    let service: any DiningService

    init(service: any DiningService) {
        self.service = service
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            let isSearching = !searchText.trimmingCharacters(in: .whitespaces).isEmpty
            state = .loaded(isSearching ? try await service.search(searchText) : try await service.restaurants(matching: filter))
        } catch {
            state = .failed("Restaurants could not be loaded.")
        }
    }

    func resetFilter() {
        filter = DiningFilter(sort: filter.sort)
    }
}
