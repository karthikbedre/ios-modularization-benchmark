import Foundation
import SearchAPI

enum SearchRanking {
    /// Lower is better: whole-title prefix, then word prefix, then anywhere else.
    static func score(_ result: SearchResult, for query: String) -> Int {
        let title = result.title.lowercased()
        let needle = query.lowercased().trimmingCharacters(in: .whitespaces)
        if title.hasPrefix(needle) { return 0 }
        if title.split(separator: " ").contains(where: { $0.hasPrefix(needle) }) { return 1 }
        if title.contains(needle) { return 2 }
        return 3
    }

    /// Groups follow `SearchScope.allCases`. Within a group, best score first, then title.
    static func rank(_ results: [SearchResult], for query: String) -> [SearchResult] {
        let order = Dictionary(uniqueKeysWithValues: SearchScope.allCases.enumerated().map { ($1, $0) })
        return results.sorted { lhs, rhs in
            if lhs.scope != rhs.scope { return order[lhs.scope]! < order[rhs.scope]! }
            let (left, right) = (score(lhs, for: query), score(rhs, for: query))
            return left != right ? left < right : lhs.title < rhs.title
        }
    }
}
