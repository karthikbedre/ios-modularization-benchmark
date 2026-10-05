#if DEBUG
import CoreModels
import Foundation

extension IssueReport {
    public static let preview = IssueReport(
        id: "issue-1", reporterID: "user-preview", category: .pothole, details: "Deep pothole in the bike lane, northbound.",
        location: GeoPoint(latitude: 40.7160, longitude: -74.0035), addressHint: "5th and Elm", createdAt: .now.addingTimeInterval(-3 * 86_400),
        updates: [
            IssueUpdate(date: .now.addingTimeInterval(-3 * 86_400), status: .submitted, note: "Report received."),
            IssueUpdate(date: .now.addingTimeInterval(-2 * 86_400), status: .scheduled, note: "Crew scheduled for this week."),
        ]
    )
}

public struct PreviewReportIssueService: ReportIssueService {
    public init() {}

    public func myReports() async throws -> [IssueReport] { [.preview] }
    public func report(id: String) async throws -> IssueReport { .preview }
    public func nearby(_ point: GeoPoint) async throws -> [IssueReport] { [] }
    public func submit(_ draft: IssueDraft) async throws -> IssueReport { .preview }
    public func support(reportID: String) async throws -> IssueReport { .preview }

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Reports", detail: "Pothole scheduled for repair")
    }
}
#endif
