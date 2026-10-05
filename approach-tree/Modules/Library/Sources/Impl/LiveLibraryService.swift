import CoreKit
import CoreModels
import Identity
import Notifications

public struct LiveLibraryService: LibraryService {
    private let identity: any IdentityService
    private let notifications: any NotificationsService
    private let latency: Latency

    public init(identity: any IdentityService, notifications: any NotificationsService, latency: Latency = .standard) {
        self.identity = identity
        self.notifications = notifications
        self.latency = latency
    }

    var dependencies: [any SummaryProviding] {
        [identity, notifications]
    }

    public func summary() async -> DomainSummary {
        await latency.wait()
        let detail = dependencies.isEmpty ? "No dependencies" : "Uses \(dependencies.count) services"
        return DomainSummary(title: "Library", detail: detail)
    }

    func allSummaries() async -> [DomainSummary] {
        var summaries = [await summary()]
        for dependency in dependencies {
            summaries.append(await dependency.summary())
        }
        return summaries
    }
}
