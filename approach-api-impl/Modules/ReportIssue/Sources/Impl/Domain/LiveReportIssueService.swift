import CoreKit
import CoreModels
import Foundation
import IdentityAPI
import NotificationsAPI
import PlacesAPI
import ReportIssueAPI

public struct LiveReportIssueService: ReportIssueService {
    static let minimumDetails = 10
    static let duplicateRadiusMeters = 75.0
    static let nearbyRadiusMeters = 1_000.0

    private let repository: any ReportsRepository
    private let identity: any IdentityService
    private let places: any PlacesService
    private let notifications: any NotificationsService
    private let dates: DateProvider
    private let makeID: @Sendable () -> String

    init(
        repository: any ReportsRepository,
        identity: any IdentityService,
        places: any PlacesService,
        notifications: any NotificationsService,
        dates: DateProvider = .live,
        makeID: @escaping @Sendable () -> String = { String(Int.random(in: 1000...9999)) }
    ) {
        self.repository = repository
        self.identity = identity
        self.places = places
        self.notifications = notifications
        self.dates = dates
        self.makeID = makeID
    }

    public func myReports() async throws -> [IssueReport] {
        let reporterID = try await identity.currentUser().id
        return try await advanced().filter { $0.reporterID == reporterID }.sorted { $0.createdAt > $1.createdAt }
    }

    public func report(id: String) async throws -> IssueReport {
        guard let report = try await advanced().first(where: { $0.id == id }) else { throw ReportIssueError.reportNotFound }
        return report
    }

    public func nearby(_ point: GeoPoint) async throws -> [IssueReport] {
        let reporterID = try await identity.currentUser().id
        return try await advanced()
            .filter { $0.reporterID != reporterID && $0.isOpen }
            .map { ($0, meters(from: point, to: $0.location)) }
            .filter { $0.1 <= Self.nearbyRadiusMeters }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    public func submit(_ draft: IssueDraft) async throws -> IssueReport {
        let details = draft.details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard details.count >= Self.minimumDetails else { throw ReportIssueError.detailsTooShort(minimum: Self.minimumDetails) }
        let reporterID = try await identity.currentUser().id

        if !draft.confirmedNotDuplicate, let duplicate = try await advanced().first(where: {
            $0.isOpen && $0.category == draft.category && meters(from: draft.location, to: $0.location) <= Self.duplicateRadiusMeters
        }) {
            throw ReportIssueError.possibleDuplicate(reportID: duplicate.id)
        }

        let now = dates.now
        let report = IssueReport(
            id: "issue-\(makeID())", reporterID: reporterID, category: draft.category, details: details, location: draft.location,
            addressHint: draft.addressHint.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: now,
            updates: [IssueUpdate(date: now, status: .submitted, note: "Report received.")]
        )
        try await repository.update { $0.append(report) }
        _ = try? await notifications.post(NotificationDraft(
            title: "\(draft.category.title) reported",
            body: "Thanks. We will let you know when a crew is scheduled. Reference \(report.id).",
            category: .report,
            sourceDomain: "ReportIssue"
        ))
        return report
    }

    public func support(reportID: String) async throws -> IssueReport {
        let supporterID = try await identity.currentUser().id
        let now = dates.now
        return try await repository.update { reports in
            guard let index = reports.firstIndex(where: { $0.id == reportID }) else { throw ReportIssueError.reportNotFound }
            guard reports[index].reporterID != supporterID else { throw ReportIssueError.cannotSupportOwnReport }
            reports[index].supporterIDs.insert(supporterID)
            return IssueTimeline.advance(reports[index], to: now)
        }
    }

    public func summary() async -> DomainSummary {
        guard let reports = try? await myReports() else {
            return DomainSummary(title: "Reports", detail: "Unavailable")
        }
        let open = reports.filter(\.isOpen)
        guard let latest = open.first else {
            return DomainSummary(title: "Reports", detail: reports.isEmpty ? "Spot something? Report it" : "All your reports are resolved")
        }
        return DomainSummary(title: "Reports", detail: "\(open.count) open · \(latest.category.title) \(latest.status.title.lowercased())")
    }

    private func advanced() async throws -> [IssueReport] {
        let now = dates.now
        return try await repository.load().map { IssueTimeline.advance($0, to: now) }
    }

    private func meters(from a: GeoPoint, to b: GeoPoint) -> Double {
        places.distance(from: a, to: b).converted(to: .meters).value
    }
}
