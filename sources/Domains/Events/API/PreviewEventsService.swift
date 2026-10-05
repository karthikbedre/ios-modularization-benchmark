#if DEBUG
import CoreModels
import Foundation

extension CityEvent {
    public static let preview = CityEvent(
        id: "event-jazz", title: "Autumn Jazz Night", summary: "Three local trios on the harbor stage, with food trucks from 5 PM.",
        category: .music, start: .now.addingTimeInterval(3 * 86_400), end: .now.addingTimeInterval(3 * 86_400 + 10_800),
        venuePlaceID: "place-amphitheater", venueName: "Harbor Amphitheater", organizer: "Harborfront Arts",
        priceFrom: .usd(18), isFeatured: true, tags: ["outdoor", "jazz"]
    )
}

public struct PreviewEventsService: EventsService {
    public init() {}

    public func upcoming(category: EventCategory?) async throws -> [CityEvent] { [.preview] }
    public func featured() async throws -> [CityEvent] { [.preview] }
    public func event(id: String) async throws -> CityEvent { .preview }
    public func search(_ text: String) async throws -> [CityEvent] { [.preview] }

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Events", detail: "Autumn Jazz Night this week")
    }
}
#endif
