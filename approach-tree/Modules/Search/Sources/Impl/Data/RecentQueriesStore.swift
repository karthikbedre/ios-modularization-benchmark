actor RecentQueriesStore {
    static let limit = 8

    private(set) var queries: [String] = []

    init(queries: [String] = []) {
        self.queries = queries
    }

    /// Most recent first, case-insensitively deduplicated.
    func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        queries.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        queries.insert(trimmed, at: 0)
        queries = Array(queries.prefix(Self.limit))
    }

    func clear() {
        queries = []
    }
}
