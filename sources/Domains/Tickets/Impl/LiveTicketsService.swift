import CoreKit
import CoreModels
import IdentityAPI
import TicketsAPI
import WalletAPI

public struct LiveTicketsService: TicketsService {
    private let wallet: any WalletService
    private let identity: any IdentityService
    private let latency: Latency

    public init(wallet: any WalletService, identity: any IdentityService, latency: Latency = .standard) {
        self.wallet = wallet
        self.identity = identity
        self.latency = latency
    }

    var dependencies: [any SummaryProviding] {
        [wallet, identity]
    }

    public func summary() async -> DomainSummary {
        await latency.wait()
        let detail = dependencies.isEmpty ? "No dependencies" : "Uses \(dependencies.count) services"
        return DomainSummary(title: "Tickets", detail: detail)
    }

    func allSummaries() async -> [DomainSummary] {
        var summaries = [await summary()]
        for dependency in dependencies {
            summaries.append(await dependency.summary())
        }
        return summaries
    }
}
