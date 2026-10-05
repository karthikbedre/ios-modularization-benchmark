import Observation
import SearchAPI

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var scopes = Set(SearchScope.allCases)
    private(set) var response: SearchResponse?
    private(set) var recent: [String] = []

    private let service: any SearchService

    init(service: any SearchService) {
        self.service = service
    }

    var groups: [(scope: SearchScope, results: [SearchResult])] {
        let results = response?.results ?? []
        return SearchScope.allCases.compactMap { scope in
            let matching = results.filter { $0.scope == scope }
            return matching.isEmpty ? nil : (scope, matching)
        }
    }

    func loadRecent() async {
        recent = await service.recentQueries()
    }

    /// Runs as the resident types. Recording a query waits for an explicit submit.
    func search() async {
        let current = query
        let result = await service.search(current, in: scopes)
        guard current == query else { return }
        response = result
    }

    func submit() async {
        await service.record(query: query)
        await loadRecent()
    }

    func toggle(_ scope: SearchScope) {
        if scopes.contains(scope) {
            guard scopes.count > 1 else { return }
            scopes.remove(scope)
        } else {
            scopes.insert(scope)
        }
    }

    func clearRecent() async {
        await service.clearRecent()
        await loadRecent()
    }
}
