#if DEBUG
import CoreModels
import Foundation

public struct PreviewAgendaService: AgendaService {
    public init() {}

    private static let entry = CalendarEntry(
        id: "c1", ownerID: "user-preview", title: "Autumn Jazz Night", start: .now.addingTimeInterval(7200), end: .now.addingTimeInterval(14_400),
        location: "Harbor Amphitheater", sourceDomain: "Tickets", sourceItemID: nil, reminder: .oneHour
    )

    public func entries(in interval: DateInterval) async throws -> [CalendarEntry] { [Self.entry] }
    public func upcoming(limit: Int) async throws -> [CalendarEntry] { [Self.entry] }
    public func add(_ draft: CalendarDraft) async throws -> CalendarEntry { Self.entry }
    public func entry(sourceDomain: String, sourceItemID: String) async throws -> CalendarEntry? { nil }
    public func remove(id: String) async throws {}

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Agenda", detail: "Next: Autumn Jazz Night")
    }
}
#endif
