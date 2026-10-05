import CoreModels
import Foundation
import Identity
import Notifications
import Places
@testable import ReportIssue
import ReportIssue
import Testing

private let now = Date(timeIntervalSince1970: 1_791_201_600)
private let hour: TimeInterval = 3600

private let origin = GeoPoint(latitude: 40.7149, longitude: -74.0055)
/// About 55 m north of `origin`.
private let close = GeoPoint(latitude: 40.71540, longitude: -74.0055)
/// About 555 m north of `origin`.
private let blocksAway = GeoPoint(latitude: 40.7199, longitude: -74.0055)

private func report(_ id: String, by reporter: String, _ category: IssueCategory = .pothole, at location: GeoPoint = close, hoursAgo: Double = 1, status: IssueStatus = .submitted) -> IssueReport {
    let created = now.addingTimeInterval(-hoursAgo * hour)
    var updates = [IssueUpdate(date: created, status: .submitted, note: "")]
    if status != .submitted { updates.append(IssueUpdate(date: created, status: status, note: "")) }
    return IssueReport(id: id, reporterID: reporter, category: category, details: "Details", location: location, addressHint: "", createdAt: created, updates: updates)
}

private struct StubIdentityService: IdentityService {
    func currentUser() async throws -> UserProfile {
        UserProfile(id: "user-1", fullName: "Sam Lee", email: "sam@example.com", phone: "5550199", residentID: "CIV-1",
                    address: Address(street: "1 Main", district: "Center", postalCode: "10000"), memberSince: now)
    }

    func update(_ update: ProfileUpdate) async throws -> UserProfile { try await currentUser() }
    func summary() async -> DomainSummary { DomainSummary(title: "Profile", detail: "") }
}

/// Flat-earth distance is plenty at city scale and keeps expectations easy to reason about.
private struct StubPlacesService: PlacesService {
    func places(in category: PlaceCategory?) async throws -> [Place] { [] }
    func place(id: String) async throws -> Place { throw PlacesError.notFound }
    func nearby(_ point: GeoPoint, radius: Measurement<UnitLength>, category: PlaceCategory?) async throws -> [NearbyPlace] { [] }

    func distance(from: GeoPoint, to: GeoPoint) -> Measurement<UnitLength> {
        let dLat = (to.latitude - from.latitude) * 111_000
        let dLon = (to.longitude - from.longitude) * 84_000
        return Measurement(value: (dLat * dLat + dLon * dLon).squareRoot(), unit: .meters)
    }

    func summary() async -> DomainSummary { DomainSummary(title: "Places", detail: "") }
}

private actor RecordingNotificationsService: NotificationsService {
    private(set) var posted: [NotificationDraft] = []

    func inbox() async throws -> [CityNotification] { [] }
    func unreadCount() async throws -> Int { 0 }
    func markRead(id: String) async throws {}
    func markAllRead() async throws {}
    func delete(id: String) async throws {}

    func post(_ draft: NotificationDraft) async throws -> CityNotification {
        posted.append(draft)
        return CityNotification(id: "n", recipientID: "user-1", title: draft.title, body: draft.body, date: now, category: draft.category, sourceDomain: draft.sourceDomain, isRead: false)
    }

    func preferences() async throws -> NotificationPreferences { NotificationPreferences() }
    func update(preferences: NotificationPreferences) async throws {}
    func summary() async -> DomainSummary { DomainSummary(title: "Inbox", detail: "") }
}

private struct Harness {
    let repository: InMemoryReportsRepository
    let notifications = RecordingNotificationsService()

    init(_ reports: [IssueReport] = []) {
        repository = InMemoryReportsRepository(reports: reports)
    }

    var service: LiveReportIssueService {
        LiveReportIssueService(repository: repository, identity: StubIdentityService(), places: StubPlacesService(),
                               notifications: notifications, dates: .fixed(now), makeID: { "9000" })
    }
}

struct IssueTimelineTests {
    @Test(arguments: [
        (1.0, IssueStatus.submitted),
        (3.0, IssueStatus.acknowledged),
        (50.0, IssueStatus.scheduled),
        (24.0 * 7, IssueStatus.resolved),
    ])
    func reportsMoveForwardWithAge(hoursAgo: Double, expected: IssueStatus) {
        #expect(IssueTimeline.advance(report("r", by: "u", hoursAgo: hoursAgo), to: now).status == expected)
    }

    @Test func existingLaterStatusIsNotOverwritten() {
        let alreadyScheduled = report("r", by: "u", hoursAgo: 3, status: .scheduled)

        let advanced = IssueTimeline.advance(alreadyScheduled, to: now)

        #expect(advanced.updates.count == 2)
        #expect(advanced.status == .scheduled)
    }
}

struct LiveReportIssueServiceTests {
    @Test func submitTrimsSavesAndConfirms() async throws {
        let harness = Harness()

        let filed = try await harness.service.submit(IssueDraft(category: .streetlight, details: "  Light out all night  ", location: origin, addressHint: " Elm "))

        #expect(filed.id == "issue-9000")
        #expect(filed.details == "Light out all night")
        #expect(filed.addressHint == "Elm")
        #expect(try await harness.service.myReports().map(\.id) == ["issue-9000"])
        #expect(await harness.notifications.posted.map(\.title) == ["Streetlight out reported"])
    }

    @Test func shortDetailsAreRejected() async {
        await #expect(throws: ReportIssueError.detailsTooShort(minimum: 10)) {
            try await Harness().service.submit(IssueDraft(category: .pothole, details: "hole", location: origin, addressHint: ""))
        }
    }

    @Test func sameCategoryCloseByIsAPossibleDuplicateUntilConfirmed() async throws {
        let harness = Harness([report("theirs", by: "user-2", at: close)])
        let draft = IssueDraft(category: .pothole, details: "Big pothole here", location: origin, addressHint: "")

        await #expect(throws: ReportIssueError.possibleDuplicate(reportID: "theirs")) { try await harness.service.submit(draft) }

        var confirmed = draft
        confirmed.confirmedNotDuplicate = true
        #expect(try await harness.service.submit(confirmed).id == "issue-9000")
    }

    @Test func differentCategoryFarAwayOrResolvedIsNotADuplicate() async throws {
        let harness = Harness([
            report("other-kind", by: "user-2", .graffiti, at: close),
            report("far", by: "user-2", at: blocksAway),
            report("fixed", by: "user-2", at: close, hoursAgo: 24 * 7),
        ])

        #expect(try await harness.service.submit(IssueDraft(category: .pothole, details: "Big pothole here", location: origin, addressHint: "")).id == "issue-9000")
    }

    @Test func nearbyShowsOthersOpenReportsClosestFirst() async throws {
        let harness = Harness([
            report("far", by: "user-2", at: blocksAway),
            report("close", by: "user-3", at: close),
            report("mine", by: "user-1", at: close),
            report("resolved", by: "user-2", at: close, hoursAgo: 24 * 7),
        ])

        #expect(try await harness.service.nearby(origin).map(\.id) == ["close", "far"])
    }

    @Test func supportingCountsOnceAndNotForOwnReports() async throws {
        let harness = Harness([report("theirs", by: "user-2"), report("mine", by: "user-1")])

        _ = try await harness.service.support(reportID: "theirs")
        let supported = try await harness.service.support(reportID: "theirs")

        #expect(supported.supporterIDs == ["user-1"])
        await #expect(throws: ReportIssueError.cannotSupportOwnReport) { try await harness.service.support(reportID: "mine") }
    }

    @Test func summaryCountsOpenReports() async {
        let harness = Harness([report("a", by: "user-1", hoursAgo: 3), report("b", by: "user-1", hoursAgo: 24 * 8)])

        #expect(await harness.service.summary().detail == "1 open · Pothole acknowledged")
    }
}
