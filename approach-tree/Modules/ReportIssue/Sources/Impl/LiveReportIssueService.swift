import CoreKit
import CoreModels
import Map
import Notifications

public struct LiveReportIssueService: ReportIssueService {
    private let map: any MapService
    private let notifications: any NotificationsService
    private let latency: Latency

    public init(map: any MapService, notifications: any NotificationsService, latency: Latency = .standard) {
        self.map = map
        self.notifications = notifications
        self.latency = latency
    }

    var dependencies: [any SummaryProviding] {
        [map, notifications]
    }

    public func summary() async -> DomainSummary {
        await latency.wait()
        let detail = dependencies.isEmpty ? "No dependencies" : "Uses \(dependencies.count) services"
        return DomainSummary(title: "ReportIssue", detail: detail)
    }

    func allSummaries() async -> [DomainSummary] {
        var summaries = [await summary()]
        for dependency in dependencies {
            summaries.append(await dependency.summary())
        }
        return summaries
    }
}
