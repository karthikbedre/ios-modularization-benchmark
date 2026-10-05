import CoreKit
import CoreModels
import IdentityAPI
import WalletAPI

public struct LiveWalletService: WalletService {
    private let identity: any IdentityService
    private let latency: Latency

    public init(identity: any IdentityService, latency: Latency = .standard) {
        self.identity = identity
        self.latency = latency
    }

    var dependencies: [any SummaryProviding] {
        [identity]
    }

    public func summary() async -> DomainSummary {
        await latency.wait()
        let detail = dependencies.isEmpty ? "No dependencies" : "Uses \(dependencies.count) services"
        return DomainSummary(title: "Wallet", detail: detail)
    }

    func allSummaries() async -> [DomainSummary] {
        var summaries = [await summary()]
        for dependency in dependencies {
            summaries.append(await dependency.summary())
        }
        return summaries
    }
}
