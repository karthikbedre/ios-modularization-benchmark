import CoreKit
import CoreModels
import MapAPI
import TransitAPI
import WalletAPI

public struct LiveTransitService: TransitService {
    private let wallet: any WalletService
    private let map: any MapService
    private let latency: Latency

    public init(wallet: any WalletService, map: any MapService, latency: Latency = .standard) {
        self.wallet = wallet
        self.map = map
        self.latency = latency
    }

    var dependencies: [any SummaryProviding] {
        [wallet, map]
    }

    public func summary() async -> DomainSummary {
        await latency.wait()
        let detail = dependencies.isEmpty ? "No dependencies" : "Uses \(dependencies.count) services"
        return DomainSummary(title: "Transit", detail: detail)
    }

    func allSummaries() async -> [DomainSummary] {
        var summaries = [await summary()]
        for dependency in dependencies {
            summaries.append(await dependency.summary())
        }
        return summaries
    }
}
