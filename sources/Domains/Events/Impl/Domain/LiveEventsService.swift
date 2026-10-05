import CoreKit
import CoreModels
import EventsAPI
import Foundation

public struct LiveEventsService: EventsService {
    private let repository: any EventsRepository
    private let dates: DateProvider

    init(repository: any EventsRepository, dates: DateProvider = .live) {
        self.repository = repository
        self.dates = dates
    }

    public func upcoming(category: EventCategory?) async throws -> [CityEvent] {
        let now = dates.now
        return try await repository.events()
            .filter { $0.end > now && (category == nil || $0.category == category) }
            .sorted { $0.start < $1.start }
    }

    public func featured() async throws -> [CityEvent] {
        try await upcoming(category: nil).filter(\.isFeatured)
    }

    public func event(id: String) async throws -> CityEvent {
        guard let event = try await repository.events().first(where: { $0.id == id }) else { throw EventsError.notFound }
        return event
    }

    public func search(_ text: String) async throws -> [CityEvent] {
        let terms = text.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !terms.isEmpty else { return [] }
        return try await upcoming(category: nil).filter { event in
            terms.allSatisfy { term in
                event.title.localizedStandardContains(term)
                    || event.summary.localizedStandardContains(term)
                    || event.venueName.localizedStandardContains(term)
                    || event.category.title.localizedStandardContains(term)
                    || event.tags.contains { $0.localizedStandardContains(term) }
            }
        }
    }

    public func summary() async -> DomainSummary {
        guard let upcoming = try? await upcoming(category: nil) else {
            return DomainSummary(title: "Events", detail: "Unavailable")
        }
        let thisWeek = upcoming.filter { $0.start < dates.now.addingTimeInterval(7 * 86_400) }
        guard let next = upcoming.first else {
            return DomainSummary(title: "Events", detail: "Nothing scheduled")
        }
        return DomainSummary(title: "Events", detail: "\(thisWeek.count) this week · next \(next.title)")
    }
}
