import CoreKit
import CoreModels
import IdentityAPI

public struct LiveIdentityService: IdentityService {
    private let latency: Latency

    public init(latency: Latency = .standard) {
        self.latency = latency
    }

    var dependencies: [any SummaryProviding] {
        []
    }

    public func summary() async -> DomainSummary {
        await latency.wait()
        let detail = dependencies.isEmpty ? "No dependencies" : "Uses \(dependencies.count) services"
        return DomainSummary(title: "Identity", detail: detail)
    }

    func allSummaries() async -> [DomainSummary] {
        var summaries = [await summary()]
        for dependency in dependencies {
            summaries.append(await dependency.summary())
        }
        return summaries
    }
}
