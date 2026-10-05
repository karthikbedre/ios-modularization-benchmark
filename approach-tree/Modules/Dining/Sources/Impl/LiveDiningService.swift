import CoreKit
import CoreModels
import Map
import Reservations

public struct LiveDiningService: DiningService {
    private let reservations: any ReservationsService
    private let map: any MapService
    private let latency: Latency

    public init(reservations: any ReservationsService, map: any MapService, latency: Latency = .standard) {
        self.reservations = reservations
        self.map = map
        self.latency = latency
    }

    var dependencies: [any SummaryProviding] {
        [reservations, map]
    }

    public func summary() async -> DomainSummary {
        await latency.wait()
        let detail = dependencies.isEmpty ? "No dependencies" : "Uses \(dependencies.count) services"
        return DomainSummary(title: "Dining", detail: detail)
    }

    func allSummaries() async -> [DomainSummary] {
        var summaries = [await summary()]
        for dependency in dependencies {
            summaries.append(await dependency.summary())
        }
        return summaries
    }
}
