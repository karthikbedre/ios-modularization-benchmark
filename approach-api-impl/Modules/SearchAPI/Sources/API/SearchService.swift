import CoreModels
import SwiftUI

public protocol SearchService: SummaryProviding {
    func search(_ text: String, in scopes: Set<SearchScope>) async -> SearchResponse
    func recentQueries() async -> [String]
    func record(query: String) async
    func clearRecent() async
}

public struct SearchEntryPoints: Sendable {
    public var search: @MainActor @Sendable () -> AnyView

    public init(search: @escaping @MainActor @Sendable () -> AnyView) {
        self.search = search
    }
}
