import CoreModels
import SwiftUI

public protocol EventsService: SummaryProviding {
    /// Events that have not ended yet, soonest first. Pass nil for every category.
    func upcoming(category: EventCategory?) async throws -> [CityEvent]
    func featured() async throws -> [CityEvent]
    func event(id: String) async throws -> CityEvent
    func search(_ text: String) async throws -> [CityEvent]
}

public struct EventsEntryPoints: Sendable {
    public var detail: @MainActor @Sendable (_ eventID: String) -> AnyView

    public init(detail: @escaping @MainActor @Sendable (_ eventID: String) -> AnyView) {
        self.detail = detail
    }
}
