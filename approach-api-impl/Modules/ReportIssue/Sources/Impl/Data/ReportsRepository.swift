import CoreKit
import Foundation
import ReportIssueAPI

protocol ReportsRepository: Sendable {
    func load() async throws -> [IssueReport]
    func update<Result: Sendable>(_ change: @Sendable (inout [IssueReport]) throws -> Result) async throws -> Result
}

actor BundleReportsRepository: ReportsRepository {
    private let loader: MockDataLoader
    private var cached: [IssueReport]?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func load() async throws -> [IssueReport] {
        if let cached { return cached }
        let reports = try await loader.load([IssueReport].self, resource: "reports", in: .module)
        if let cached { return cached }
        cached = reports
        return reports
    }

    func update<Result: Sendable>(_ change: @Sendable (inout [IssueReport]) throws -> Result) async throws -> Result {
        var reports = try await load()
        let result = try change(&reports)
        cached = reports
        return result
    }
}

actor InMemoryReportsRepository: ReportsRepository {
    private(set) var reports: [IssueReport]

    init(reports: [IssueReport]) {
        self.reports = reports
    }

    func load() async throws -> [IssueReport] { reports }

    func update<Result: Sendable>(_ change: @Sendable (inout [IssueReport]) throws -> Result) async throws -> Result {
        try change(&reports)
    }
}
