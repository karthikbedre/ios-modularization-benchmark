import CoreKit
import CoreModels
import Map
import Tickets

public struct LiveEventsService: EventsService {
    private let tickets: any TicketsService
    private let map: any MapService
    private let latency: Latency

    public init(tickets: any TicketsService, map: any MapService, latency: Latency = .standard) {
        self.tickets = tickets
        self.map = map
        self.latency = latency
    }

    var dependencies: [any SummaryProviding] {
        [tickets, map]
    }

    public func summary() async -> DomainSummary {
        await latency.wait()
        let detail = dependencies.isEmpty ? "No dependencies" : "Uses \(dependencies.count) services"
        return DomainSummary(title: "Events", detail: detail)
    }

    func allSummaries() async -> [DomainSummary] {
        var summaries = [await summary()]
        for dependency in dependencies {
            summaries.append(await dependency.summary())
        }
        return summaries
    }
}
