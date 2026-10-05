public struct DomainSummary: Hashable, Sendable {
    public var title: String
    public var detail: String

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }
}

public protocol SummaryProviding: Sendable {
    func summary() async -> DomainSummary
}
