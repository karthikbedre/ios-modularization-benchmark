import CoreModels
import Foundation
import SwiftUI

public protocol ReportIssueService: SummaryProviding {
    func myReports() async throws -> [IssueReport]
    func report(id: String) async throws -> IssueReport
    /// Open reports by other residents near `point`, closest first.
    func nearby(_ point: GeoPoint) async throws -> [IssueReport]
    /// Files the report and confirms in the inbox. Throws `possibleDuplicate` for a similar open report close by.
    func submit(_ draft: IssueDraft) async throws -> IssueReport
    /// Adds the resident's support to someone else's report instead of filing a duplicate.
    func support(reportID: String) async throws -> IssueReport
}

public struct ReportIssueEntryPoints: Sendable {
    public var newReport: @MainActor @Sendable () -> AnyView

    public init(newReport: @escaping @MainActor @Sendable () -> AnyView) {
        self.newReport = newReport
    }
}
