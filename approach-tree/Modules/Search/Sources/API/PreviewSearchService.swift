#if DEBUG
import CoreModels

public struct PreviewSearchService: SearchService {
    public init() {}

    public func search(_ text: String, in scopes: Set<SearchScope>) async -> SearchResponse {
        SearchResponse(results: [
            SearchResult(scope: .events, itemID: "event-jazz", title: "Autumn Jazz Night", subtitle: "Harbor Amphitheater"),
            SearchResult(scope: .restaurants, itemID: "rest-tidewater", title: "Tidewater Grill", subtitle: "Seafood · Harborfront"),
        ], unavailable: [])
    }

    public func recentQueries() async -> [String] { ["harbor", "jazz"] }
    public func record(query: String) async {}
    public func clearRecent() async {}

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Search", detail: "Recent: harbor")
    }
}
#endif
