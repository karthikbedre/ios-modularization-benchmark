import CoreModels
import Dining
import Events
import Foundation
import Library
import Places
import Transit

public struct LiveSearchService: SearchService {
    static let minimumQueryLength = 2

    private let events: any EventsService
    private let dining: any DiningService
    private let library: any LibraryService
    private let transit: any TransitService
    private let places: any PlacesService
    private let recent: RecentQueriesStore

    init(events: any EventsService, dining: any DiningService, library: any LibraryService, transit: any TransitService, places: any PlacesService, recent: RecentQueriesStore = RecentQueriesStore()) {
        self.events = events
        self.dining = dining
        self.library = library
        self.transit = transit
        self.places = places
        self.recent = recent
    }

    public func search(_ text: String, in scopes: Set<SearchScope>) async -> SearchResponse {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= Self.minimumQueryLength else { return SearchResponse(results: [], unavailable: []) }

        let outcomes = await withTaskGroup(of: (SearchScope, [SearchResult]?).self) { group in
            for scope in scopes {
                group.addTask { (scope, try? await self.results(in: scope, for: query)) }
            }
            var outcomes: [SearchScope: [SearchResult]?] = [:]
            for await (scope, results) in group {
                outcomes[scope] = results
            }
            return outcomes
        }
        let found = outcomes.values.compactMap { $0 }.flatMap { $0 }
        let unavailable = Set(outcomes.filter { $0.value == nil }.map { $0.key })
        return SearchResponse(results: SearchRanking.rank(found, for: query), unavailable: unavailable)
    }

    public func recentQueries() async -> [String] {
        await recent.queries
    }

    public func record(query: String) async {
        await recent.record(query)
    }

    public func clearRecent() async {
        await recent.clear()
    }

    public func summary() async -> DomainSummary {
        guard let last = await recent.queries.first else {
            return DomainSummary(title: "Search", detail: "Find events, food, books and stops")
        }
        return DomainSummary(title: "Search", detail: "Recent: \(last)")
    }

    private func results(in scope: SearchScope, for query: String) async throws -> [SearchResult] {
        switch scope {
        case .events:
            return try await events.search(query).map {
                SearchResult(scope: .events, itemID: $0.id, title: $0.title, subtitle: "\($0.start.formatted(.dateTime.weekday().month().day())) · \($0.venueName)")
            }
        case .restaurants:
            return try await dining.search(query).map {
                SearchResult(scope: .restaurants, itemID: $0.id, title: $0.name, subtitle: "\($0.cuisine.title) · \($0.district)")
            }
        case .books:
            return try await library.search(query, format: nil).map {
                SearchResult(scope: .books, itemID: $0.book.id, title: $0.book.title, subtitle: "\($0.book.author) · \($0.book.format.title)")
            }
        case .stops:
            return try await transit.stops().filter { $0.name.localizedStandardContains(query) }.map {
                SearchResult(scope: .stops, itemID: $0.id, title: $0.name, subtitle: "Transit stop")
            }
        case .places:
            return try await places.places(in: nil).filter { $0.name.localizedStandardContains(query) || $0.address.district.localizedStandardContains(query) }.map {
                SearchResult(scope: .places, itemID: $0.id, title: $0.name, subtitle: "\($0.category.title) · \($0.address.district)")
            }
        }
    }
}
